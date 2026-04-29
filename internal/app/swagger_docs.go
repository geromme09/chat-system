package app

import "github.com/geromme09/chat-system/internal/platform/response"

var _ response.ApiResponse

// swaggerUIRoute documents the bundled Swagger UI route.
// @Summary Open Swagger UI
// @Tags system
// @Produce html
// @Success 200 {string} string "Swagger UI"
// @Router /swagger/index.html [get]
func swaggerUIRoute() {}

// mediaRoute documents static media delivery.
// @Summary Get uploaded media
// @Tags media
// @Param path path string true "Media file path"
// @Success 200 {file} file
// @Failure 404 {object} response.ApiResponse
// @Router /media/{path} [get]
func mediaRoute() {}
