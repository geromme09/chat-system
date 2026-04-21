package http

import (
	"errors"
	"strings"

	"github.com/geromme09/chat-system/internal/modules/chat/app"
	"github.com/geromme09/chat-system/internal/platform/httpx"
	"github.com/geromme09/chat-system/internal/platform/response"
)

type ListConversationsHandler struct {
	service *app.Service
}

type CreateConversationHandler struct {
	service *app.Service
}

type ConversationMessagesHandler struct {
	service *app.Service
}

func NewListConversationsHandler(service *app.Service) *ListConversationsHandler {
	return &ListConversationsHandler{service: service}
}

func NewCreateConversationHandler(service *app.Service) *CreateConversationHandler {
	return &CreateConversationHandler{service: service}
}

func NewConversationMessagesHandler(service *app.Service) *ConversationMessagesHandler {
	return &ConversationMessagesHandler{service: service}
}

// Serve lists current user's conversations.
// @Summary List conversations
// @Tags chat
// @Produce json
// @Success 200 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Router /api/v1/chat/conversations [get]
func (h *ListConversationsHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	conversations, err := h.service.ListConversations(ctx.Request.Context(), userID)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(conversations, nil)
}

// Serve creates a conversation.
// @Summary Create conversation
// @Tags chat
// @Accept json
// @Produce json
// @Param request body app.CreateConversationInput true "Conversation payload"
// @Success 201 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Router /api/v1/chat/conversations [post]
func (h *CreateConversationHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input app.CreateConversationInput
	if err := ctx.DecodeJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	conversation, err := h.service.CreateConversation(ctx.Request.Context(), userID, input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Created(conversation)
}

// Serve routes conversation message operations.
// @Summary List or send conversation messages
// @Tags chat
// @Accept json
// @Produce json
// @Success 200 {object} response.ApiResponse
// @Success 201 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 404 {object} response.ApiResponse
// @Failure 405 {object} response.ApiResponse
// @Router /api/v1/chat/conversations/{id}/messages [get]
// @Router /api/v1/chat/conversations/{id}/messages [post]
func (h *ConversationMessagesHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	path := strings.TrimPrefix(ctx.Request.URL.Path, "/api/v1/chat/conversations/")
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) != 2 || parts[1] != "messages" {
		return response.NotFound("resource not found")
	}

	conversationID := parts[0]
	switch ctx.Request.Method {
	case "GET":
		messages, err := h.service.ListMessages(ctx.Request.Context(), userID, conversationID)
		if err != nil {
			return response.BadRequest(err)
		}
		return response.Ok(messages, nil)
	case "POST":
		var input app.SendMessageInput
		if err := ctx.DecodeJSON(&input); err != nil {
			return response.BadRequest(errors.New("invalid request body"))
		}

		message, err := h.service.SendMessage(ctx.Request.Context(), userID, conversationID, input)
		if err != nil {
			return response.BadRequest(err)
		}
		return response.Created(message)
	default:
		return response.MethodNotAllowed()
	}
}
