package http

import (
	"errors"
	"strconv"
	"strings"

	notificationapp "github.com/geromme09/chat-system/internal/modules/notification/app"
	"github.com/geromme09/chat-system/internal/platform/httpx"
	"github.com/geromme09/chat-system/internal/platform/response"
)

type Handler struct {
	service *notificationapp.Service
}

const notificationPathPrefix = "/api/v1/notifications/"

func NewHandler(service *notificationapp.Service) *Handler {
	return &Handler{service: service}
}

// Serve handles notification listing and read state.
func (h *Handler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	switch ctx.Request.Method {
	case "GET":
		page, _ := strconv.Atoi(ctx.Query("page"))
		limit, _ := strconv.Atoi(ctx.Query("limit"))
		notifications, err := h.service.ListNotifications(ctx.Request.Context(), userID, notificationapp.ListNotificationsInput{
			Page:  page,
			Limit: limit,
		})
		if err != nil {
			return response.BadRequest(err)
		}
		return response.Ok(notifications, nil)
	case "POST":
		if ctx.Request.URL.Path == "/api/v1/notifications/read-all" {
			if err := h.service.MarkAllRead(ctx.Request.Context(), userID); err != nil {
				return response.BadRequest(err)
			}
			return response.Ok(map[string]any{"status": "ok"}, nil)
		}

		notificationID, action, ok := parseNotificationPath(ctx.Request.URL.Path)
		if !ok {
			return response.NotFound("resource not found")
		}
		if action != "read" {
			return response.NotFound("resource not found")
		}
		if err := h.service.MarkRead(ctx.Request.Context(), userID, notificationID); err != nil {
			return response.BadRequest(err)
		}
		return response.Ok(map[string]any{"status": "ok"}, nil)
	default:
		return response.MethodNotAllowed()
	}
}

func parseNotificationPath(path string) (notificationID string, action string, ok bool) {
	path = strings.TrimPrefix(path, notificationPathPrefix)
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) != 2 {
		return "", "", false
	}

	return parts[0], parts[1], true
}
