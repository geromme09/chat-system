package app

import (
	"net/http/httptest"
	"testing"
	"time"
)

func TestRateLimiterAllowsBurstThenBlocks(t *testing.T) {
	t.Parallel()

	limiter := newRateLimiter(1, 2)
	now := time.Now()

	if !limiter.allow("127.0.0.1", now) {
		t.Fatal("expected first request to pass")
	}
	if !limiter.allow("127.0.0.1", now) {
		t.Fatal("expected second request to pass")
	}
	if limiter.allow("127.0.0.1", now) {
		t.Fatal("expected third request to be rate limited")
	}
}

func TestRateLimiterRefillsOverTime(t *testing.T) {
	t.Parallel()

	limiter := newRateLimiter(2, 2)
	now := time.Now()

	if !limiter.allow("127.0.0.1", now) || !limiter.allow("127.0.0.1", now) {
		t.Fatal("expected initial burst to pass")
	}
	if limiter.allow("127.0.0.1", now) {
		t.Fatal("expected request to be blocked before refill")
	}
	if !limiter.allow("127.0.0.1", now.Add(600*time.Millisecond)) {
		t.Fatal("expected limiter to refill after enough time")
	}
}

func TestClientIPPrefersForwardedHeaders(t *testing.T) {
	t.Parallel()

	request := httptest.NewRequest("GET", "/healthz", nil)
	request.RemoteAddr = "127.0.0.1:4000"
	request.Header.Set("X-Forwarded-For", "203.0.113.9, 10.0.0.1")

	if got := clientIP(request); got != "203.0.113.9" {
		t.Fatalf("expected forwarded IP, got %q", got)
	}
}
