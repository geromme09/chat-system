package http

import (
	"errors"
	"strings"

	"github.com/geromme09/chat-system/internal/modules/chat/app"
	"github.com/geromme09/chat-system/internal/platform/httpx"
	"github.com/geromme09/chat-system/internal/platform/response"
)

const (
	chatConversationsPathPrefix = "/api/v1/chat/conversations/"
	chatMessagesPathSegment     = "messages"
	chatReadPathSegment         = "read"
)

type ListConversationsHandler struct {
	service *app.Service
}

type CreateConversationHandler struct {
	service *app.Service
}

type ConversationDetailHandler struct {
	service *app.Service
}

type UnreadCountHandler struct {
	service *app.Service
}

func NewListConversationsHandler(service *app.Service) *ListConversationsHandler {
	return &ListConversationsHandler{service: service}
}

func NewCreateConversationHandler(service *app.Service) *CreateConversationHandler {
	return &CreateConversationHandler{service: service}
}

func NewConversationDetailHandler(service *app.Service) *ConversationDetailHandler {
	return &ConversationDetailHandler{service: service}
}

func NewUnreadCountHandler(service *app.Service) *UnreadCountHandler {
	return &UnreadCountHandler{service: service}
}

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

func (h *ConversationDetailHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	conversationID, action, valid := parseConversationPath(ctx.Request.URL.Path)
	if !valid {
		return response.NotFound("resource not found")
	}

	switch {
	case ctx.Request.Method == "GET" && action == chatMessagesPathSegment:
		messages, err := h.service.ListMessages(ctx.Request.Context(), userID, conversationID)
		if err != nil {
			return response.BadRequest(err)
		}
		return response.Ok(messages, nil)
	case ctx.Request.Method == "POST" && action == chatMessagesPathSegment:
		var input app.SendMessageInput
		if err := ctx.DecodeJSON(&input); err != nil {
			return response.BadRequest(errors.New("invalid request body"))
		}

		message, err := h.service.SendMessage(ctx.Request.Context(), userID, conversationID, input)
		if err != nil {
			return response.BadRequest(err)
		}
		return response.Created(message)
	case ctx.Request.Method == "POST" && action == chatReadPathSegment:
		result, err := h.service.MarkConversationRead(ctx.Request.Context(), userID, conversationID)
		if err != nil {
			return response.BadRequest(err)
		}
		return response.Ok(result, nil)
	default:
		return response.MethodNotAllowed()
	}
}

func (h *UnreadCountHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	unreadCount, err := h.service.GetUnreadCount(ctx.Request.Context(), userID)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(unreadCount, nil)
}

func parseConversationPath(path string) (conversationID string, action string, ok bool) {
	path = strings.TrimPrefix(path, chatConversationsPathPrefix)
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) != 2 {
		return "", "", false
	}

	return parts[0], parts[1], true
}
