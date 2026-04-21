package http

import (
	"strconv"

	"github.com/geromme09/chat-system/internal/modules/sport/app"
	"github.com/geromme09/chat-system/internal/platform/httpx"
	"github.com/geromme09/chat-system/internal/platform/response"
)

type ListSportsHandler struct {
	service *app.Service
}

func NewListSportsHandler(service *app.Service) *ListSportsHandler {
	return &ListSportsHandler{service: service}
}

// Serve lists sports with optional search and pagination.
// @Summary List sports
// @Tags sports
// @Produce json
// @Param q query string false "Search query"
// @Param page query int false "Page number"
// @Param limit query int false "Page size"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Router /api/v1/sports [get]
func (h *ListSportsHandler) Serve(ctx httpx.Context) response.ApiResponse {
	page, _ := strconv.Atoi(ctx.Query("page"))
	limit, _ := strconv.Atoi(ctx.Query("limit"))

	result, err := h.service.ListSports(ctx.Request.Context(), app.ListSportsInput{
		Query: ctx.Query("q"),
		Page:  page,
		Limit: limit,
	})
	if err != nil {
		return response.BadRequest(err)
	}

	return response.Ok(result, nil)
}
