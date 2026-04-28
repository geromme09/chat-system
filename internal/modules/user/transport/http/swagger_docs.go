package http

import "github.com/geromme09/chat-system/internal/platform/response"

var _ response.ApiResponse

// acceptFriendRequest documents POST /api/v1/friends/requests/{id}/accept.
// @Summary Accept friend request
// @Tags friends
// @Produce json
// @Param id path string true "Friend request ID"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 404 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/friends/requests/{id}/accept [post]
func acceptFriendRequest() {}

// declineFriendRequest documents POST /api/v1/friends/requests/{id}/decline.
// @Summary Decline friend request
// @Tags friends
// @Produce json
// @Param id path string true "Friend request ID"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Failure 404 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/friends/requests/{id}/decline [post]
func declineFriendRequest() {}
