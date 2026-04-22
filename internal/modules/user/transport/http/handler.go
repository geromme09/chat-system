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
	if err := ctx.DecodeJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
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
// @Router /api/v1/profile/me [put]
func (h *UpdateMeHandler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	var input app.UpdateProfileInput
	if err := ctx.DecodeJSON(&input); err != nil {
		return response.BadRequest(errors.New("invalid request body"))
	}

	profile, err := h.service.UpdateProfile(ctx.Request.Context(), userID, input)
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(profile, nil)
}

// Serve searches users by username or display name.
// @Summary Search users
// @Tags users
// @Produce json
// @Success 200 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
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
