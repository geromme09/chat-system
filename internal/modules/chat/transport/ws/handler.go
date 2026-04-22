package ws

import (
	"net/http"
	"strings"

	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/response"
)

type Handler struct {
	tokenManager auth.TokenManager
	hub          *Hub
}

func NewHandler(tokenManager auth.TokenManager, hub *Hub) *Handler {
	return &Handler{
		tokenManager: tokenManager,
		hub:          hub,
	}
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	header := strings.TrimSpace(r.Header.Get("Authorization"))
	if header == "" {
		token := strings.TrimSpace(r.URL.Query().Get("token"))
		if token != "" {
			header = "Bearer " + token
		}
	}
	if !strings.HasPrefix(header, "Bearer ") {
		response.WriteError(w, http.StatusUnauthorized, "missing or invalid bearer token")
		return
	}

	userID, err := h.tokenManager.Parse(strings.TrimPrefix(header, "Bearer "))
	if err != nil {
		response.WriteError(w, http.StatusUnauthorized, "invalid bearer token")
		return
	}

	h.hub.ServeHTTP(w, r, userID)
}
