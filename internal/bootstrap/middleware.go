package bootstrap

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"math"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/httpx"
	"github.com/geromme09/chat-system/internal/platform/response"
)

func authMiddleware(tokenManager auth.TokenManager, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			response.WriteError(w, http.StatusUnauthorized, "missing or invalid bearer token")
			return
		}

		userID, err := tokenManager.Parse(strings.TrimPrefix(header, "Bearer "))
		if err != nil {
			response.WriteError(w, http.StatusUnauthorized, "invalid bearer token")
			return
		}

		ctx := httpx.WithUserID(r.Context(), userID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

type statusRecorder struct {
	http.ResponseWriter
	statusCode  int
	body        bytes.Buffer
	bodyMaxSize int
	size        int
}

func (r *statusRecorder) Write(body []byte) (int, error) {
	r.size += len(body)
	if r.bodyMaxSize > 0 && r.body.Len() < r.bodyMaxSize {
		remaining := r.bodyMaxSize - r.body.Len()
		if remaining > len(body) {
			remaining = len(body)
		}
		_, _ = r.body.Write(body[:remaining])
	}

	return r.ResponseWriter.Write(body)
}

func (r *statusRecorder) WriteHeader(statusCode int) {
	r.statusCode = statusCode
	r.ResponseWriter.WriteHeader(statusCode)
}

func (r *statusRecorder) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	hijacker, ok := r.ResponseWriter.(http.Hijacker)
	if !ok {
		return nil, nil, errors.New("response writer does not support hijacking")
	}

	return hijacker.Hijack()
}

func (r *statusRecorder) Flush() {
	if flusher, ok := r.ResponseWriter.(http.Flusher); ok {
		flusher.Flush()
	}
}

func (r *statusRecorder) Unwrap() http.ResponseWriter {
	return r.ResponseWriter
}

func requestLoggingMiddleware(logger *slog.Logger, logBodies bool, bodyMaxBytes int, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestID := requestIDFromHeader(r)
		ctx := httpx.WithRequestID(r.Context(), requestID)
		r = r.WithContext(ctx)
		w.Header().Set("X-Request-ID", requestID)

		requestBody, requestSize := captureRequestBody(r, logBodies, bodyMaxBytes)
		recorder := &statusRecorder{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
			bodyMaxSize:    bodyMaxBytes,
		}
		start := time.Now()

		next.ServeHTTP(recorder, r)

		attrs := []any{
			"http request",
			"request_id", requestID,
			"method", r.Method,
			"path", r.URL.Path,
			"query", r.URL.RawQuery,
			"status", recorder.statusCode,
			"remote_addr", clientIP(r),
			"duration_ms", time.Since(start).Milliseconds(),
			"request_bytes", requestSize,
			"response_bytes", recorder.size,
		}
		if userID, ok := httpx.CurrentUserID(r.Context()); ok {
			attrs = append(attrs, "user_id", userID)
		}
		if logBodies {
			attrs = append(
				attrs,
				"request_body", redactSensitiveJSON(requestBody),
				"response_body", redactSensitiveJSON(recorder.body.String()),
			)
		}

		logger.Info(attrs[0].(string), attrs[1:]...)
	})
}

type rateLimiter struct {
	mu      sync.Mutex
	buckets map[string]*clientBucket
	rate    float64
	burst   float64
}

type clientBucket struct {
	tokens     float64
	lastRefill time.Time
}

func newRateLimiter(requestsPerSecond, burst int) *rateLimiter {
	if requestsPerSecond <= 0 {
		requestsPerSecond = 5
	}
	if burst <= 0 {
		burst = requestsPerSecond * 3
	}

	return &rateLimiter{
		buckets: map[string]*clientBucket{},
		rate:    float64(requestsPerSecond),
		burst:   float64(burst),
	}
}

func (l *rateLimiter) allow(key string, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	bucket, ok := l.buckets[key]
	if !ok {
		l.buckets[key] = &clientBucket{
			tokens:     l.burst - 1,
			lastRefill: now,
		}
		return true
	}

	elapsed := now.Sub(bucket.lastRefill).Seconds()
	bucket.tokens = math.Min(l.burst, bucket.tokens+(elapsed*l.rate))
	bucket.lastRefill = now

	if bucket.tokens < 1 {
		return false
	}

	bucket.tokens--
	return true
}

func (l *rateLimiter) middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		clientKey := clientIP(r)
		if !l.allow(clientKey, time.Now()) {
			w.Header().Set("Retry-After", "1")
			response.WriteError(w, http.StatusTooManyRequests, "rate limit exceeded")
			return
		}

		next.ServeHTTP(w, r)
	})
}

func clientIP(r *http.Request) string {
	forwarded := strings.TrimSpace(strings.Split(r.Header.Get("X-Forwarded-For"), ",")[0])
	if forwarded != "" {
		return forwarded
	}

	realIP := strings.TrimSpace(r.Header.Get("X-Real-IP"))
	if realIP != "" {
		return realIP
	}

	host := r.RemoteAddr
	if strings.Contains(host, ":") {
		if value, _, err := net.SplitHostPort(host); err == nil {
			return value
		}
	}

	return host
}

func captureRequestBody(r *http.Request, enabled bool, maxBytes int) (string, int) {
	if r.Body == nil {
		return "", 0
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		r.Body = io.NopCloser(bytes.NewReader(nil))
		return "", 0
	}
	r.Body = io.NopCloser(bytes.NewReader(body))

	if !enabled {
		return "", len(body)
	}

	if maxBytes > 0 && len(body) > maxBytes {
		return string(body[:maxBytes]), len(body)
	}

	return string(body), len(body)
}

func requestIDFromHeader(r *http.Request) string {
	for _, header := range []string{"X-Request-ID", "X-Correlation-ID"} {
		if value := strings.TrimSpace(r.Header.Get(header)); value != "" {
			return value
		}
	}

	return newRequestID()
}

func newRequestID() string {
	buffer := make([]byte, 12)
	if _, err := rand.Read(buffer); err != nil {
		return strconv.FormatInt(time.Now().UnixNano(), 10)
	}

	return hex.EncodeToString(buffer)
}

func redactSensitiveJSON(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}

	var decoded any
	if err := json.Unmarshal([]byte(value), &decoded); err != nil {
		return value
	}

	redactJSONValue(decoded)

	encoded, err := json.Marshal(decoded)
	if err != nil {
		return value
	}

	return string(encoded)
}

func redactJSONValue(value any) {
	switch typed := value.(type) {
	case map[string]any:
		for key, nested := range typed {
			if isSensitiveKey(key) {
				typed[key] = "[REDACTED]"
				continue
			}
			redactJSONValue(nested)
		}
	case []any:
		for _, nested := range typed {
			redactJSONValue(nested)
		}
	}
}

func isSensitiveKey(key string) bool {
	switch strings.ToLower(strings.TrimSpace(key)) {
	case "password", "password_hash", "token", "access_token", "refresh_token", "authorization", "secret", "token_secret":
		return true
	default:
		return false
	}
}
