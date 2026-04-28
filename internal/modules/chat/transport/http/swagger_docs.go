package http

import (
	"github.com/geromme09/chat-system/internal/modules/chat/app"
	"github.com/geromme09/chat-system/internal/platform/response"
)

var (
	_ app.SendMessageInput
	_ response.ApiResponse
)

// listConversationMessages documents GET /api/v1/chat/conversations/{id}/messages.
// @Summary List conversation messages
// @Tags chat
// @Produce json
// @Param id path string true "Conversation ID"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 404 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/chat/conversations/{id}/messages [get]
func listConversationMessages() {}

// sendConversationMessage documents POST /api/v1/chat/conversations/{id}/messages.
// @Summary Send conversation message
// @Tags chat
// @Accept json
// @Produce json
// @Param id path string true "Conversation ID"
// @Param request body app.SendMessageInput true "Message payload"
// @Success 201 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 404 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/chat/conversations/{id}/messages [post]
func sendConversationMessage() {}

// markConversationRead documents POST /api/v1/chat/conversations/{id}/read.
// @Summary Mark conversation read
// @Tags chat
// @Produce json
// @Param id path string true "Conversation ID"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 404 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/chat/conversations/{id}/read [post]
func markConversationRead() {}
