package http

import (
	"context"
	"errors"
	"strconv"

	"github.com/gin-gonic/gin"

	feedapp "github.com/geromme09/chat-system/internal/modules/feed/app"
	feeddomain "github.com/geromme09/chat-system/internal/modules/feed/domain"
	userapp "github.com/geromme09/chat-system/internal/modules/user/app"
	"github.com/geromme09/chat-system/internal/platform/httpx"
	"github.com/geromme09/chat-system/internal/platform/response"
)

type userProfileReader interface {
	GetMe(ctx context.Context, userID string) (userapp.AuthResult, error)
}

type ListPostsHandler struct {
	service *feedapp.Service
}

type GetPostHandler struct {
	service *feedapp.Service
}

type CreatePostHandler struct {
	service     *feedapp.Service
	userService userProfileReader
}

type UpdatePostHandler struct {
	service *feedapp.Service
}

type DeletePostHandler struct {
	service *feedapp.Service
}

type ToggleReactionHandler struct {
	service *feedapp.Service
}

type LikePostHandler struct {
	service *feedapp.Service
}

type UnlikePostHandler struct {
	service *feedapp.Service
}

type HidePostHandler struct {
	service *feedapp.Service
}

type ReportPostHandler struct {
	service *feedapp.Service
}

type ListCommentsHandler struct {
	service *feedapp.Service
}

type CreateCommentHandler struct {
	service     *feedapp.Service
	userService userProfileReader
}

func NewListPostsHandler(service *feedapp.Service) *ListPostsHandler {
	return &ListPostsHandler{service: service}
}

func NewGetPostHandler(service *feedapp.Service) *GetPostHandler {
	return &GetPostHandler{service: service}
}

func NewCreatePostHandler(service *feedapp.Service, userService userProfileReader) *CreatePostHandler {
	return &CreatePostHandler{service: service, userService: userService}
}

func NewUpdatePostHandler(service *feedapp.Service) *UpdatePostHandler {
	return &UpdatePostHandler{service: service}
}

func NewDeletePostHandler(service *feedapp.Service) *DeletePostHandler {
	return &DeletePostHandler{service: service}
}

func NewToggleReactionHandler(service *feedapp.Service) *ToggleReactionHandler {
	return &ToggleReactionHandler{service: service}
}

func NewLikePostHandler(service *feedapp.Service) *LikePostHandler {
	return &LikePostHandler{service: service}
}

func NewUnlikePostHandler(service *feedapp.Service) *UnlikePostHandler {
	return &UnlikePostHandler{service: service}
}

func NewHidePostHandler(service *feedapp.Service) *HidePostHandler {
	return &HidePostHandler{service: service}
}

func NewReportPostHandler(service *feedapp.Service) *ReportPostHandler {
	return &ReportPostHandler{service: service}
}

func NewListCommentsHandler(service *feedapp.Service) *ListCommentsHandler {
	return &ListCommentsHandler{service: service}
}

func NewCreateCommentHandler(service *feedapp.Service, userService userProfileReader) *CreateCommentHandler {
	return &CreateCommentHandler{service: service, userService: userService}
}

func (h *ListPostsHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := currentUserID(c)
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	limit, _ := strconv.Atoi(c.Query("limit"))
	posts, err := h.service.ListPosts(c.Request.Context(), userID, feeddomain.ListPostsInput{
		Cursor:       c.Query("cursor"),
		AuthorUserID: c.Query("author_user_id"),
		Limit:        limit,
	})
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(posts, nil)
}

func (h *GetPostHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := currentUserID(c)
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	post, err := h.service.GetPost(c.Request.Context(), userID, c.Param("id"))
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(post, nil)
}

func (h *CreatePostHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := currentUserID(c)
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input feedapp.CreatePostInput
	if httpx.IsMultipart(c.Request) {
		if err := httpx.ParseMultipart(c.Request); err != nil {
			return response.BadRequest(errors.New("invalid multipart body"))
		}
		input.Caption = httpx.FormString(c.Request, "caption")
		imageDataURL, err := httpx.FileDataURL(c.Request, "image")
		if err != nil {
			return response.BadRequest(err)
		}
		input.ImageDataURL = imageDataURL
	} else if err := c.ShouldBindJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	author, apiRes := h.currentAuthor(c, userID)
	if apiRes != nil {
		return *apiRes
	}

	post, err := h.service.CreatePost(c.Request.Context(), author, input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Created(post)
}

func (h *UpdatePostHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := currentUserID(c)
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input feedapp.UpdatePostInput
	if err := c.ShouldBindJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	post, err := h.service.UpdatePost(c.Request.Context(), userID, c.Param("id"), input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(post, nil)
}

func (h *DeletePostHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := currentUserID(c)
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	if err := h.service.DeletePost(c.Request.Context(), userID, c.Param("id")); err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(map[string]bool{"deleted": true}, nil)
}

func (h *ToggleReactionHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := currentUserID(c)
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	post, err := h.service.ToggleReaction(c.Request.Context(), userID, c.Param("id"))
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(post, nil)
}

func (h *LikePostHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := currentUserID(c)
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	post, err := h.service.SetReaction(c.Request.Context(), userID, c.Param("id"), true)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(post, nil)
}

func (h *UnlikePostHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := currentUserID(c)
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	post, err := h.service.SetReaction(c.Request.Context(), userID, c.Param("id"), false)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(post, nil)
}

func (h *HidePostHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := currentUserID(c)
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	if err := h.service.HidePost(c.Request.Context(), userID, c.Param("id")); err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(map[string]bool{"hidden": true}, nil)
}

func (h *ReportPostHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := currentUserID(c)
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input feedapp.ReportPostInput
	if err := c.ShouldBindJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	report, err := h.service.ReportPost(c.Request.Context(), userID, c.Param("id"), input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Created(report)
}

func (h *ListCommentsHandler) Handle(c *gin.Context) response.ApiResponse {
	limit, _ := strconv.Atoi(c.Query("limit"))
	comments, err := h.service.ListComments(c.Request.Context(), c.Param("id"), feeddomain.ListCommentsInput{
		Cursor: c.Query("cursor"),
		Limit:  limit,
	})
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(comments, nil)
}

func (h *CreateCommentHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := currentUserID(c)
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input feedapp.CreateCommentInput
	if err := c.ShouldBindJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	author, apiRes := h.currentAuthor(c, userID)
	if apiRes != nil {
		return *apiRes
	}

	comment, err := h.service.CreateComment(c.Request.Context(), author, c.Param("id"), input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Created(comment)
}

func (h *CreatePostHandler) currentAuthor(c *gin.Context, userID string) (feeddomain.Author, *response.ApiResponse) {
	me, err := h.userService.GetMe(c.Request.Context(), userID)
	if err != nil {
		apiRes := response.BadRequest(err)
		return feeddomain.Author{}, &apiRes
	}

	return feeddomain.Author{
		UserID:      me.User.ID,
		Username:    me.User.Username,
		DisplayName: me.Profile.DisplayName,
		AvatarURL:   me.Profile.AvatarURL,
		City:        me.Profile.City,
	}, nil
}

func (h *CreateCommentHandler) currentAuthor(c *gin.Context, userID string) (feeddomain.Author, *response.ApiResponse) {
	me, err := h.userService.GetMe(c.Request.Context(), userID)
	if err != nil {
		apiRes := response.BadRequest(err)
		return feeddomain.Author{}, &apiRes
	}

	return feeddomain.Author{
		UserID:      me.User.ID,
		Username:    me.User.Username,
		DisplayName: me.Profile.DisplayName,
		AvatarURL:   me.Profile.AvatarURL,
		City:        me.Profile.City,
	}, nil
}

func currentUserID(c *gin.Context) (string, bool) {
	return httpx.CurrentUserID(c.Request.Context())
}
