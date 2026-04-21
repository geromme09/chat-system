package http

import (
	"errors"
	"net/http"

	"github.com/geromme09/chat-system/internal/modules/user/app"
	"github.com/geromme09/chat-system/internal/platform/httpx"
)

type Handler struct {
	service *app.Service
}

func NewHandler(service *app.Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) SignUp(w http.ResponseWriter, r *http.Request) {
	var input app.SignUpInput
	if err := httpx.DecodeJSON(r, &input); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	result, err := h.service.SignUp(r.Context(), input)
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusCreated, result)
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var input app.LoginInput
	if err := httpx.DecodeJSON(r, &input); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	result, err := h.service.Login(r.Context(), input)
	if err != nil {
		if errors.Is(err, app.ErrInvalidCredentials) {
			httpx.WriteError(w, http.StatusUnauthorized, err.Error())
			return
		}
		httpx.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) GetMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := httpx.CurrentUserID(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, "missing user context")
		return
	}

	result, err := h.service.GetMe(r.Context(), userID)
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := httpx.CurrentUserID(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, "missing user context")
		return
	}

	var input app.UpdateProfileInput
	if err := httpx.DecodeJSON(r, &input); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	profile, err := h.service.UpdateProfile(r.Context(), userID, input)
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}

	httpx.WriteJSON(w, http.StatusOK, profile)
}
