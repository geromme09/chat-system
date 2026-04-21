package bootstrap

import (
	"net/http"
	"strings"

	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/httpx"
)

func authMiddleware(tokenManager auth.TokenManager, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			httpx.WriteError(w, http.StatusUnauthorized, "missing or invalid bearer token")
			return
		}

		userID, err := tokenManager.Parse(strings.TrimPrefix(header, "Bearer "))
		if err != nil {
			httpx.WriteError(w, http.StatusUnauthorized, "invalid bearer token")
			return
		}

		ctx := httpx.WithUserID(r.Context(), userID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
