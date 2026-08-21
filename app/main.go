// 쿠버네티스 학습용 실습 애플리케이션입니다.
//
// 클러스터에서 관찰하고 싶은 상황을 요청 하나로 만들어 낼 수 있도록, 일부러 다음과 같은
// 엔드포인트를 갖추고 있습니다.
//
//	GET  /              현재 Pod 의 신원과 버전, 누적 요청 수를 JSON 으로 돌려줍니다.
//	GET  /healthz       liveness 프로브용. live 상태가 아니면 500 을 돌려줍니다.
//	GET  /readyz        readiness 프로브용. ready 상태가 아니면 503 을 돌려줍니다.
//	POST /toggle/ready  ready 상태를 뒤집습니다. 트래픽에서 빠지는 과정을 관찰합니다.
//	POST /toggle/live   live 상태를 뒤집습니다. kubelet 이 컨테이너를 재시작하게 만듭니다.
//	POST /crash         프로세스를 즉시 종료합니다. CrashLoopBackOff 를 만들어 봅니다.
//	GET  /burn?seconds=5&threads=2   CPU 를 소모합니다. 리소스 제한과 HPA 실습용입니다.
//	GET  /sleep?seconds=3            응답을 지연시킵니다. 타임아웃 실습용입니다.
//	GET  /env           환경 변수를 모두 보여줍니다. ConfigMap·Secret 주입을 확인합니다.
//	GET  /file?path=... 파일 내용을 보여줍니다. 볼륨 마운트를 확인합니다.
//
// 환경 변수로 동작을 바꿀 수 있습니다.
//
//	PORT            수신 포트 (기본 8080)
//	APP_VERSION     버전 표시를 덮어씁니다 (기본값은 빌드 시 주입된 값)
//	MESSAGE         응답에 함께 실어 보낼 문구 (ConfigMap 실습에서 사용)
//	STARTUP_DELAY   시작을 이 초만큼 지연시킵니다 (startupProbe 실습에서 사용)
//	READY_AFTER     시작 후 이 초가 지난 뒤에 ready 가 됩니다 (기본 0)
//	SHUTDOWN_DELAY  SIGTERM 을 받은 뒤 이 초만큼 기다린 다음 종료합니다 (기본 5)
//
// 주의: /env 와 /file 은 Secret 의 내용까지 그대로 드러냅니다. 학습에서 "Secret 은
// 암호화가 아니다"를 확인하기 위한 장치이므로, 실제 서비스에는 절대 두지 마십시오.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"time"
)

// 빌드할 때 -ldflags "-X main.version=v2" 로 주입합니다.
var version = "dev"

type server struct {
	startedAt time.Time
	ready     atomic.Bool
	live      atomic.Bool
	requests  atomic.Int64
}

func main() {
	log.SetFlags(log.LstdFlags | log.LUTC)

	if d := envDuration("STARTUP_DELAY", 0); d > 0 {
		log.Printf("시작을 %s 지연합니다 (STARTUP_DELAY)", d)
		time.Sleep(d)
	}

	s := &server{startedAt: time.Now()}
	s.live.Store(true)

	readyAfter := envDuration("READY_AFTER", 0)
	if readyAfter > 0 {
		log.Printf("%s 뒤에 ready 상태가 됩니다 (READY_AFTER)", readyAfter)
		go func() {
			time.Sleep(readyAfter)
			s.ready.Store(true)
			log.Print("ready 상태가 되었습니다")
		}()
	} else {
		s.ready.Store(true)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", s.handleRoot)
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/readyz", s.handleReadyz)
	mux.HandleFunc("/toggle/ready", s.handleToggleReady)
	mux.HandleFunc("/toggle/live", s.handleToggleLive)
	mux.HandleFunc("/crash", s.handleCrash)
	mux.HandleFunc("/burn", s.handleBurn)
	mux.HandleFunc("/sleep", s.handleSleep)
	mux.HandleFunc("/env", s.handleEnv)
	mux.HandleFunc("/file", s.handleFile)

	addr := ":" + getenv("PORT", "8080")
	srv := &http.Server{
		Addr:              addr,
		Handler:           s.withLogging(mux),
		ReadHeaderTimeout: 10 * time.Second,
	}

	// SIGTERM 을 받은 뒤의 처리 순서가 무중단 배포의 핵심입니다.
	// 1. readiness 를 실패로 바꿔서 Service 의 대상 목록에서 빠지게 한다.
	// 2. 이미 전달 중인 요청이 끝날 시간을 준다(SHUTDOWN_DELAY).
	// 3. 그다음에 서버를 닫는다.
	// 이 순서를 지키지 않으면, 종료 중인 Pod 으로 새 요청이 흘러들어 502 가 납니다.
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer stop()

	go func() {
		<-ctx.Done()
		delay := envDuration("SHUTDOWN_DELAY", 5*time.Second)
		log.Printf("종료 신호를 받았습니다. ready 를 내리고 %s 기다립니다", delay)
		s.ready.Store(false)
		time.Sleep(delay)

		shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Printf("정상 종료에 실패했습니다: %v", err)
		}
	}()

	log.Printf("버전 %s, 주소 %s 에서 수신을 시작합니다 (hostname=%s)", displayVersion(), addr, hostname())
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("서버가 멈췄습니다: %v", err)
	}
	log.Print("종료했습니다")
}

// ---------------------------------------------------------------------------
// 핸들러
// ---------------------------------------------------------------------------

type rootResponse struct {
	Version   string `json:"version"`
	Hostname  string `json:"hostname"`
	Message   string `json:"message,omitempty"`
	Requests  int64  `json:"requests"`
	UptimeSec int    `json:"uptime_sec"`
	Ready     bool   `json:"ready"`
	Live      bool   `json:"live"`
	PodName   string `json:"pod_name,omitempty"`
	PodIP     string `json:"pod_ip,omitempty"`
	Namespace string `json:"namespace,omitempty"`
	NodeName  string `json:"node_name,omitempty"`
}

func (s *server) handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	writeJSON(w, http.StatusOK, rootResponse{
		Version:   displayVersion(),
		Hostname:  hostname(),
		Message:   os.Getenv("MESSAGE"),
		Requests:  s.requests.Load(),
		UptimeSec: int(time.Since(s.startedAt).Seconds()),
		Ready:     s.ready.Load(),
		Live:      s.live.Load(),
		// 아래 값들은 Downward API 로 주입해야 채워집니다. 06단계에서 다룹니다.
		PodName:   os.Getenv("POD_NAME"),
		PodIP:     os.Getenv("POD_IP"),
		Namespace: os.Getenv("POD_NAMESPACE"),
		NodeName:  os.Getenv("NODE_NAME"),
	})
}

func (s *server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	if !s.live.Load() {
		http.Error(w, "unhealthy", http.StatusInternalServerError)
		return
	}
	fmt.Fprintln(w, "ok")
}

func (s *server) handleReadyz(w http.ResponseWriter, r *http.Request) {
	if !s.ready.Load() {
		// readiness 실패는 503 으로 알립니다. 이 Pod 은 Service 의 대상 목록에서 빠지지만
		// 재시작되지는 않습니다. liveness 실패와의 차이가 여기에 있습니다.
		http.Error(w, "not ready", http.StatusServiceUnavailable)
		return
	}
	fmt.Fprintln(w, "ready")
}

func (s *server) handleToggleReady(w http.ResponseWriter, r *http.Request) {
	v := !s.ready.Load()
	s.ready.Store(v)
	log.Printf("ready 상태를 %v 로 바꿨습니다", v)
	writeJSON(w, http.StatusOK, map[string]bool{"ready": v})
}

func (s *server) handleToggleLive(w http.ResponseWriter, r *http.Request) {
	v := !s.live.Load()
	s.live.Store(v)
	log.Printf("live 상태를 %v 로 바꿨습니다", v)
	writeJSON(w, http.StatusOK, map[string]bool{"live": v})
}

func (s *server) handleCrash(w http.ResponseWriter, r *http.Request) {
	log.Print("/crash 요청을 받았습니다. 프로세스를 종료합니다")
	// 응답을 먼저 흘려보낸 뒤 종료합니다.
	fmt.Fprintln(w, "crashing")
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}
	go func() {
		time.Sleep(100 * time.Millisecond)
		os.Exit(1)
	}()
}

func (s *server) handleBurn(w http.ResponseWriter, r *http.Request) {
	seconds := queryInt(r, "seconds", 5)
	threads := queryInt(r, "threads", 1)
	if seconds > 300 {
		seconds = 300
	}
	if threads < 1 {
		threads = 1
	}
	if threads > runtime.NumCPU()*2 {
		threads = runtime.NumCPU() * 2
	}

	log.Printf("CPU 를 %d초 동안 %d개 흐름으로 소모합니다", seconds, threads)
	deadline := time.Now().Add(time.Duration(seconds) * time.Second)
	for i := 0; i < threads; i++ {
		go func() {
			x := 0
			for time.Now().Before(deadline) {
				for j := 0; j < 1_000_000; j++ {
					x += j
				}
			}
			_ = x
		}()
	}
	writeJSON(w, http.StatusAccepted, map[string]any{
		"burning_seconds": seconds,
		"threads":         threads,
		"num_cpu":         runtime.NumCPU(),
	})
}

func (s *server) handleSleep(w http.ResponseWriter, r *http.Request) {
	seconds := queryInt(r, "seconds", 3)
	if seconds > 300 {
		seconds = 300
	}
	time.Sleep(time.Duration(seconds) * time.Second)
	fmt.Fprintf(w, "slept %ds\n", seconds)
}

func (s *server) handleEnv(w http.ResponseWriter, r *http.Request) {
	env := os.Environ()
	sort.Strings(env)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	for _, e := range env {
		fmt.Fprintln(w, e)
	}
}

func (s *server) handleFile(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Query().Get("path")
	if path == "" {
		http.Error(w, "path 질의 매개변수가 필요합니다. 예: /file?path=/etc/config/app.conf",
			http.StatusBadRequest)
		return
	}
	data, err := os.ReadFile(path)
	if err != nil {
		http.Error(w, fmt.Sprintf("읽을 수 없습니다: %v", err), http.StatusNotFound)
		return
	}
	const limit = 64 * 1024
	if len(data) > limit {
		data = data[:limit]
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Write(data)
}

// ---------------------------------------------------------------------------
// 미들웨어와 보조 함수
// ---------------------------------------------------------------------------

// 요청마다 한 줄을 남깁니다. kubectl logs 로 흐름을 관찰하기 위한 것입니다.
func (s *server) withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := s.requests.Add(1)
		start := time.Now()
		next.ServeHTTP(w, r)
		// 프로브 요청은 아주 잦으므로, 상태가 정상일 때는 로그를 줄입니다.
		if isProbe(r.URL.Path) && s.ready.Load() && s.live.Load() {
			return
		}
		log.Printf("%s %s %s (%d번째, %s)",
			r.Method, r.URL.Path, r.RemoteAddr, n, time.Since(start).Round(time.Millisecond))
	})
}

func isProbe(path string) bool {
	return path == "/healthz" || path == "/readyz"
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	if err := enc.Encode(v); err != nil {
		log.Printf("응답을 쓰지 못했습니다: %v", err)
	}
}

func displayVersion() string {
	if v := os.Getenv("APP_VERSION"); v != "" {
		return v
	}
	return version
}

func hostname() string {
	// Pod 안에서는 이 값이 Pod 이름과 같습니다. 롤링 업데이트로 Pod 이 바뀌는 것을
	// 응답만 보고 알 수 있는 이유가 여기에 있습니다.
	h, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return h
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// 초 단위 숫자 또는 "1500ms" 처럼 단위가 붙은 값을 모두 받아들입니다.
func envDuration(key string, fallback time.Duration) time.Duration {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	if n, err := strconv.Atoi(raw); err == nil {
		return time.Duration(n) * time.Second
	}
	if d, err := time.ParseDuration(raw); err == nil {
		return d
	}
	log.Printf("%s 값 %q 를 해석할 수 없어 기본값 %s 를 씁니다", key, raw, fallback)
	return fallback
}

func queryInt(r *http.Request, key string, fallback int) int {
	raw := r.URL.Query().Get(key)
	if raw == "" {
		return fallback
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		return fallback
	}
	return n
}
