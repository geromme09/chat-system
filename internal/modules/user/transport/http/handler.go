package http

import (
	"errors"

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
