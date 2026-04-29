package http

import (
	"errors"

	"github.com/gin-gonic/gin"

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

type ListConversationMessagesHandler struct {
	service *app.Service
}

type SendConversationMessageHandler struct {
	service *app.Service
}

type MarkConversationReadHandler struct {
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

func NewListConversationMessagesHandler(service *app.Service) *ListConversationMessagesHandler {
	return &ListConversationMessagesHandler{service: service}
}

func NewSendConversationMessageHandler(service *app.Service) *SendConversationMessageHandler {
	return &SendConversationMessageHandler{service: service}
}

func NewMarkConversationReadHandler(service *app.Service) *MarkConversationReadHandler {
	return &MarkConversationReadHandler{service: service}
}

func NewUnreadCountHandler(service *app.Service) *UnreadCountHandler {
	return &UnreadCountHandler{service: service}
}

func (h *ListConversationsHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	conversations, err := h.service.ListConversations(c.Request.Context(), userID)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(conversations, nil)
}

func (h *CreateConversationHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input app.CreateConversationInput
	if err := c.ShouldBindJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	conversation, err := h.service.CreateConversation(c.Request.Context(), userID, input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Created(conversation)
}

func (h *ListConversationMessagesHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	messages, err := h.service.ListMessages(c.Request.Context(), userID, c.Param("id"))
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(messages, nil)
}

func (h *SendConversationMessageHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input app.SendMessageInput
	if err := c.ShouldBindJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	message, err := h.service.SendMessage(c.Request.Context(), userID, c.Param("id"), input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Created(message)
}

func (h *MarkConversationReadHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	result, err := h.service.MarkConversationRead(c.Request.Context(), userID, c.Param("id"))
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(result, nil)
}

func (h *UnreadCountHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	unreadCount, err := h.service.GetUnreadCount(c.Request.Context(), userID)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(unreadCount, nil)
}
