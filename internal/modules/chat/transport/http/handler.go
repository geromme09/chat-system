package http

import (
	"net/http"
	"strings"

	"github.com/geromme09/chat-system/internal/modules/chat/app"
	"github.com/geromme09/chat-system/internal/platform/httpx"
)

type Handler struct {
	service *app.Service
}

func NewHandler(service *app.Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) ListConversations(w http.ResponseWriter, r *http.Request) {
	userID, ok := httpx.CurrentUserID(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, "missing user context")
		return
	}

	conversations, err := h.service.ListConversations(r.Context(), userID)
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusOK, conversations)
}

func (h *Handler) CreateConversation(w http.ResponseWriter, r *http.Request) {
	userID, ok := httpx.CurrentUserID(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, "missing user context")
		return
	}

	var input app.CreateConversationInput
	if err := httpx.DecodeJSON(r, &input); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	conversation, err := h.service.CreateConversation(r.Context(), userID, input)
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusCreated, conversation)
}

func (h *Handler) RouteConversationMessages(w http.ResponseWriter, r *http.Request) {
	userID, ok := httpx.CurrentUserID(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, "missing user context")
		return
	}

	path := strings.TrimPrefix(r.URL.Path, "/api/v1/chat/conversations/")
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) != 2 || parts[1] != "messages" {
		http.NotFound(w, r)
		return
	}

	conversationID := parts[0]
	switch r.Method {
	case http.MethodGet:
		messages, err := h.service.ListMessages(r.Context(), userID, conversationID)
		if err != nil {
			httpx.WriteError(w, http.StatusBadRequest, err.Error())
			return
		}
		httpx.WriteJSON(w, http.StatusOK, messages)
	case http.MethodPost:
		var input app.SendMessageInput
		if err := httpx.DecodeJSON(r, &input); err != nil {
			httpx.WriteError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		message, err := h.service.SendMessage(r.Context(), userID, conversationID, input)
		if err != nil {
			httpx.WriteError(w, http.StatusBadRequest, err.Error())
			return
		}
		httpx.WriteJSON(w, http.StatusCreated, message)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}
