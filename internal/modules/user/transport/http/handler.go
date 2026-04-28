package http

import (
	"errors"
	"strconv"
	"strings"

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

// Serve handles user signup.
// @Summary Sign up
// @Tags auth
// @Accept json
// @Produce json
// @Param request body app.SignUpInput true "Sign up payload"
// @Success 201 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Router /api/v1/auth/signup [post]
func (h *SignUpHandler) Serve(ctx httpx.Context) response.ApiResponse {
	var input app.SignUpInput
	if httpx.IsMultipart(ctx.Request) {
		if err := httpx.ParseMultipart(ctx.Request); err != nil {
			return response.BadRequest(errors.New("invalid multipart body"))
		}
		input.Email = httpx.FormString(ctx.Request, "email")
		input.Username = httpx.FormString(ctx.Request, "username")
		input.Password = httpx.FormString(ctx.Request, "password")
		input.DisplayName = httpx.FormString(ctx.Request, "display_name")
		input.Bio = httpx.FormString(ctx.Request, "bio")
		input.City = httpx.FormString(ctx.Request, "city")
		input.Country = httpx.FormString(ctx.Request, "country")
		avatarDataURL, err := httpx.FileDataURL(ctx.Request, "avatar")
		if err != nil {
			return response.BadRequest(err)
		}
		input.AvatarDataURL = avatarDataURL
	} else {
		if err := ctx.DecodeJSON(&input); err != nil {
			return response.BadRequest(errors.New("invalid request body"))
		}
	}

	result, err := h.service.SignUp(ctx.Request.Context(), input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Created(result)
}

// Serve handles user login.
// @Summary Log in
// @Tags auth
// @Accept json
// @Produce json
// @Param request body app.LoginInput true "Login payload"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Router /api/v1/auth/login [post]
func (h *LoginHandler) Serve(ctx httpx.Context) response.ApiResponse {
	var input app.LoginInput
	if err := ctx.DecodeJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	result, err := h.service.Login(ctx.Request.Context(), input)
	if err != nil {
		if errors.Is(err, app.ErrInvalidCredentials) {
			return response.Unauthorized(err)
		}
		return response.BadRequest(err)
	}

	return response.Ok(result, nil)
}

// Serve returns the current authenticated user.
// @Summary Get my profile
// @Tags profile
// @Produce json
// @Success 200 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/profile/me [get]
func (h *GetMeHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	result, err := h.service.GetMe(ctx.Request.Context(), userID)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(result, nil)
}

// Serve updates the current authenticated profile.
// @Summary Update my profile
// @Tags profile
// @Accept json
// @Produce json
// @Param request body app.UpdateProfileInput true "Profile payload"
// @Success 200 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/profile/me [put]
func (h *UpdateMeHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input app.UpdateProfileInput
	if httpx.IsMultipart(ctx.Request) {
		if err := httpx.ParseMultipart(ctx.Request); err != nil {
			return response.BadRequest(errors.New("invalid multipart body"))
		}
		input.DisplayName = httpx.FormString(ctx.Request, "display_name")
		input.Bio = httpx.FormString(ctx.Request, "bio")
		input.City = httpx.FormString(ctx.Request, "city")
		input.Country = httpx.FormString(ctx.Request, "country")
		input.Gender = httpx.FormString(ctx.Request, "gender")
		input.HobbiesText = httpx.FormString(ctx.Request, "hobbies_text")
		input.Visible = parseBoolFormValue(ctx.Request.FormValue("visible"), true)
		avatarDataURL, err := httpx.FileDataURL(ctx.Request, "avatar")
		if err != nil {
			return response.BadRequest(err)
		}
		input.AvatarDataURL = avatarDataURL
	} else {
		if err := ctx.DecodeJSON(&input); err != nil {
			return response.BadRequest(errors.New("invalid request body"))
		}
	}

	profile, err := h.service.UpdateProfile(ctx.Request.Context(), userID, input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(profile, nil)
}

func parseBoolFormValue(value string, fallback bool) bool {
	parsed, err := strconv.ParseBool(strings.TrimSpace(value))
	if err != nil {
		return fallback
	}
	return parsed
}

// Serve returns a public profile for the requested user.
// @Summary Get public profile
// @Tags profile
// @Produce json
// @Param userID path string true "User ID"
// @Success 200 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/profile/{userID} [get]
func (h *GetProfileHandler) Serve(ctx httpx.Context) response.ApiResponse {
	actorUserID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	path := strings.TrimPrefix(ctx.Request.URL.Path, "/api/v1/profile/")
	targetUserID := strings.Trim(path, "/")
	if targetUserID == "" || targetUserID == "me" || strings.Contains(targetUserID, "/") {
		return response.NotFound("resource not found")
	}

	profile, err := h.service.GetPublicProfile(ctx.Request.Context(), actorUserID, targetUserID)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(profile, nil)
}

// Serve searches users by username or display name.
// @Summary Search users
// @Tags users
// @Produce json
// @Param q query string false "Search query"
// @Param limit query int false "Maximum number of results"
// @Success 200 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/users/search [get]
func (h *SearchUsersHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	limit, _ := strconv.Atoi(ctx.Query("limit"))
	results, err := h.service.SearchUsers(ctx.Request.Context(), app.SearchUsersInput{
		Query:       ctx.Query("q"),
		Limit:       limit,
		ExcludeUser: userID,
	})
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(results, nil)
}

// Serve sends a friend request.
// @Summary Send friend request
// @Tags friends
// @Accept json
// @Produce json
// @Param request body app.SendFriendRequestInput true "Friend request payload"
// @Success 201 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/friends/requests [post]
func (h *SendFriendRequestHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input app.SendFriendRequestInput
	if err := ctx.DecodeJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	friendRequest, err := h.service.SendFriendRequest(ctx.Request.Context(), userID, input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Created(friendRequest)
}

// Serve lists incoming friend requests.
// @Summary List incoming friend requests
// @Tags friends
// @Produce json
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/friends/requests/incoming [get]
func (h *IncomingFriendRequestsHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	requests, err := h.service.ListIncomingFriendRequests(ctx.Request.Context(), userID)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(requests, nil)
}

// Serve accepts or declines a friend request.
func (h *RespondFriendRequestHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	path := strings.TrimPrefix(ctx.Request.URL.Path, "/api/v1/friends/requests/")
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) != 2 {
		return response.NotFound("resource not found")
	}

	friendRequest, err := h.service.RespondToFriendRequest(
		ctx.Request.Context(),
		userID,
		parts[0],
		h.status,
	)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(friendRequest, nil)
}

// Serve lists accepted friends.
// @Summary List friends
// @Tags friends
// @Produce json
// @Param page query int false "Page number"
// @Param limit query int false "Page size"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/friends [get]
func (h *ListFriendsHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	page, _ := strconv.Atoi(ctx.Query("page"))
	limit, _ := strconv.Atoi(ctx.Query("limit"))
	friends, err := h.service.ListFriends(ctx.Request.Context(), userID, app.ListFriendsInput{
		Page:  page,
		Limit: limit,
	})
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(friends, nil)
}
