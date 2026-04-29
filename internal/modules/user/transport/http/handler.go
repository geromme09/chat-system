package http

import (
	"errors"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/geromme09/chat-system/internal/modules/user/app"
	"github.com/geromme09/chat-system/internal/platform/httpx"
	"github.com/geromme09/chat-system/internal/platform/response"
)

type SignUpHandler struct {
	service *app.Service
}

type LoginHandler struct {
	service *app.Service
}

type GetMeHandler struct {
	service *app.Service
}

type UpdateMeHandler struct {
	service *app.Service
}

type GetProfileHandler struct {
	service *app.Service
}

type SearchUsersHandler struct {
	service *app.Service
}

type SendFriendRequestHandler struct {
	service *app.Service
}

type IncomingFriendRequestsHandler struct {
	service *app.Service
}

type RespondFriendRequestHandler struct {
	service *app.Service
	status  string
}

type ListFriendsHandler struct {
	service *app.Service
}

func NewSignUpHandler(service *app.Service) *SignUpHandler {
	return &SignUpHandler{service: service}
}

func NewLoginHandler(service *app.Service) *LoginHandler {
	return &LoginHandler{service: service}
}

func NewGetMeHandler(service *app.Service) *GetMeHandler {
	return &GetMeHandler{service: service}
}

func NewUpdateMeHandler(service *app.Service) *UpdateMeHandler {
	return &UpdateMeHandler{service: service}
}

func NewGetProfileHandler(service *app.Service) *GetProfileHandler {
	return &GetProfileHandler{service: service}
}

func NewSearchUsersHandler(service *app.Service) *SearchUsersHandler {
	return &SearchUsersHandler{service: service}
}

func NewSendFriendRequestHandler(service *app.Service) *SendFriendRequestHandler {
	return &SendFriendRequestHandler{service: service}
}

func NewIncomingFriendRequestsHandler(service *app.Service) *IncomingFriendRequestsHandler {
	return &IncomingFriendRequestsHandler{service: service}
}

func NewRespondFriendRequestHandler(service *app.Service, status string) *RespondFriendRequestHandler {
	return &RespondFriendRequestHandler{service: service, status: status}
}

func NewListFriendsHandler(service *app.Service) *ListFriendsHandler {
	return &ListFriendsHandler{service: service}
}

func (h *SignUpHandler) Handle(c *gin.Context) response.ApiResponse {
	var input app.SignUpInput
	if httpx.IsMultipart(c.Request) {
		if err := httpx.ParseMultipart(c.Request); err != nil {
			return response.BadRequest(errors.New("invalid multipart body"))
		}
		input.Email = httpx.FormString(c.Request, "email")
		input.Username = httpx.FormString(c.Request, "username")
		input.Password = httpx.FormString(c.Request, "password")
		input.DisplayName = httpx.FormString(c.Request, "display_name")
		input.Bio = httpx.FormString(c.Request, "bio")
		input.City = httpx.FormString(c.Request, "city")
		input.Country = httpx.FormString(c.Request, "country")
		avatarDataURL, err := httpx.FileDataURL(c.Request, "avatar")
		if err != nil {
			return response.BadRequest(err)
		}
		input.AvatarDataURL = avatarDataURL
	} else if err := c.ShouldBindJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	result, err := h.service.SignUp(c.Request.Context(), input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Created(result)
}

func (h *LoginHandler) Handle(c *gin.Context) response.ApiResponse {
	var input app.LoginInput
	if err := c.ShouldBindJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	result, err := h.service.Login(c.Request.Context(), input)
	if err != nil {
		if errors.Is(err, app.ErrInvalidCredentials) {
			return response.Unauthorized(err)
		}
		return response.BadRequest(err)
	}

	return response.Ok(result, nil)
}

func (h *GetMeHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	result, err := h.service.GetMe(c.Request.Context(), userID)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(result, nil)
}

func (h *UpdateMeHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input app.UpdateProfileInput
	if httpx.IsMultipart(c.Request) {
		if err := httpx.ParseMultipart(c.Request); err != nil {
			return response.BadRequest(errors.New("invalid multipart body"))
		}
		input.DisplayName = httpx.FormString(c.Request, "display_name")
		input.Bio = httpx.FormString(c.Request, "bio")
		input.City = httpx.FormString(c.Request, "city")
		input.Country = httpx.FormString(c.Request, "country")
		input.Gender = httpx.FormString(c.Request, "gender")
		input.HobbiesText = httpx.FormString(c.Request, "hobbies_text")
		input.Visible = parseBoolFormValue(c.Request.FormValue("visible"), true)
		avatarDataURL, err := httpx.FileDataURL(c.Request, "avatar")
		if err != nil {
			return response.BadRequest(err)
		}
		input.AvatarDataURL = avatarDataURL
	} else if err := c.ShouldBindJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	profile, err := h.service.UpdateProfile(c.Request.Context(), userID, input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(profile, nil)
}

func (h *GetProfileHandler) Handle(c *gin.Context) response.ApiResponse {
	actorUserID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	targetUserID := strings.TrimSpace(c.Param("userID"))
	if targetUserID == "" || targetUserID == "me" {
		return response.NotFound("resource not found")
	}

	profile, err := h.service.GetPublicProfile(c.Request.Context(), actorUserID, targetUserID)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(profile, nil)
}

func (h *SearchUsersHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	limit, _ := strconv.Atoi(c.Query("limit"))
	results, err := h.service.SearchUsers(c.Request.Context(), app.SearchUsersInput{
		Query:       c.Query("q"),
		Limit:       limit,
		ExcludeUser: userID,
	})
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(results, nil)
}

func (h *SendFriendRequestHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input app.SendFriendRequestInput
	if err := c.ShouldBindJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	friendRequest, err := h.service.SendFriendRequest(c.Request.Context(), userID, input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Created(friendRequest)
}

func (h *IncomingFriendRequestsHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	requests, err := h.service.ListIncomingFriendRequests(c.Request.Context(), userID)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(requests, nil)
}

func (h *RespondFriendRequestHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	friendRequest, err := h.service.RespondToFriendRequest(c.Request.Context(), userID, c.Param("id"), h.status)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(friendRequest, nil)
}

func (h *ListFriendsHandler) Handle(c *gin.Context) response.ApiResponse {
	userID, ok := httpx.CurrentUserID(c.Request.Context())
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	page, _ := strconv.Atoi(c.Query("page"))
	limit, _ := strconv.Atoi(c.Query("limit"))
	friends, err := h.service.ListFriends(c.Request.Context(), userID, app.ListFriendsInput{
		Page:  page,
		Limit: limit,
	})
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(friends, nil)
}

func parseBoolFormValue(value string, fallback bool) bool {
	parsed, err := strconv.ParseBool(strings.TrimSpace(value))
	if err != nil {
		return fallback
	}
	return parsed
}
