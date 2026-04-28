package http

import "github.com/geromme09/chat-system/internal/platform/response"

var _ response.ApiResponse

// listNotifications documents GET /api/v1/notifications.
// @Summary List notifications
// @Tags notifications
// @Produce json
// @Param page query int false "Page number"
// @Param limit query int false "Page size"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/notifications [get]
func listNotifications() {}

// markAllNotificationsRead documents POST /api/v1/notifications/read-all.
// @Summary Mark all notifications read
// @Tags notifications
// @Produce json
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/notifications/read-all [post]
func markAllNotificationsRead() {}

// markNotificationRead documents POST /api/v1/notifications/{id}/read.
// @Summary Mark notification read
// @Tags notifications
// @Produce json
// @Param id path string true "Notification ID"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 404 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/notifications/{id}/read [post]
func markNotificationRead() {}
