// Sample microservice used to demonstrate the platform. Deliberately simple:
// the point of this repo is the platform around it, not the app logic.
// Exposes /healthz (liveness), /readyz (readiness, checks DB), /metrics (Prometheus).
package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/lib/pq"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	httpRequests = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total HTTP requests by path and status",
	}, []string{"path", "status"})

	requestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "Request latency in seconds",
		Buckets: prometheus.DefBuckets,
	}, []string{"path"})
)

var db *sql.DB

func main() {
	dsn := os.Getenv("DATABASE_URL") // populated from the External-Secrets-synced K8s Secret
	if dsn != "" {
		var err error
		db, err = sql.Open("postgres", dsn)
		if err != nil {
			log.Printf("warning: could not open db connection: %v", err)
		}
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", instrument("/healthz", healthzHandler))
	mux.HandleFunc("/readyz", instrument("/readyz", readyzHandler))
	mux.HandleFunc("/", instrument("/", rootHandler))
	mux.Handle("/metrics", promhttp.Handler())

	srv := &http.Server{
		Addr:         ":8080",
		Handler:      mux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	log.Println("listening on :8080")
	log.Fatal(srv.ListenAndServe())
}

func instrument(path string, h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &statusRecorder{ResponseWriter: w, status: 200}
		h(rw, r)
		httpRequests.WithLabelValues(path, http.StatusText(rw.status)).Inc()
		requestDuration.WithLabelValues(path).Observe(time.Since(start).Seconds())
	}
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

// Liveness: process is up. Never checks external dependencies -
// a slow DB should not cause the kubelet to kill and restart a healthy pod.
func healthzHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

// Readiness: safe to receive traffic. Checks the DB - if it fails, the pod
// is pulled from Service endpoints but NOT restarted.
func readyzHandler(w http.ResponseWriter, r *http.Request) {
	if db != nil {
		if err := db.Ping(); err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			_ = json.NewEncoder(w).Encode(map[string]string{"status": "db unreachable"})
			return
		}
	}
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ready"})
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	_ = json.NewEncoder(w).Encode(map[string]string{
		"service": "platform-sample-app",
		"version": os.Getenv("APP_VERSION"),
	})
}
