package http

import (
	"errors"
	"strconv"

	"github.com/gin-gonic/gin"

	notificationapp "github.com/geromme09/chat-system/internal/modules/notification/app"
	"github.com/geromme09/chat-system/internal/platform/httpx"
	"github.com/geromme09/chat-system/internal/platform/response"
)

type ListNotificationsHandler struct {
	service *notificationapp.Service
}

type MarkAllReadHandler struct {
	service *notificationapp.Service
}

type MarkNotificationReadHandler struct {
	service *notificationapp.Service
}

func NewListNotificationsHandler(service *notificationapp.Service) *ListNotificationsHandler {
	return &ListNotificationsHandler{service: service}
}

func NewMarkAllReadHandler(service *notificationapp.Service) *MarkAllReadHandler {
	return &MarkAllReadHandler{service: service}
}

func NewMarkNotificationReadHandler(service *notificationapp.Service) *MarkNotificationReadHandler {
	return &MarkNotificationReadHandler{service: service}
}

func (h *ListNotificationsHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	page, _ := strconv.Atoi(c.Query("page"))
	limit, _ := strconv.Atoi(c.Query("limit"))
	notifications, err := h.service.ListNotifications(c.Request.Context(), userID, notificationapp.ListNotificationsInput{
		Page:  page,
		Limit: limit,
	})
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(notifications, nil)
}

func (h *MarkAllReadHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	if err := h.service.MarkAllRead(c.Request.Context(), userID); err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(map[string]any{"status": "ok"}, nil)
}

func (h *MarkNotificationReadHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	if err := h.service.MarkRead(c.Request.Context(), userID, c.Param("id")); err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(map[string]any{"status": "ok"}, nil)
}
