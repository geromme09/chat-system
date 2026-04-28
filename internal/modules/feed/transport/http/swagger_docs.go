package http

import (
	"github.com/geromme09/chat-system/internal/modules/feed/app"
	"github.com/geromme09/chat-system/internal/platform/response"
)

var (
	_ app.CreatePostInput
	_ app.CreateCommentInput
	_ app.UpdatePostInput
	_ app.ReportPostInput
	_ response.ApiResponse
)

// listFeedPosts documents GET /api/v1/feed.
// @Summary List feed posts
// @Tags feed
// @Produce json
// @Param cursor query string false "Pagination cursor"
// @Param author_user_id query string false "Filter by author user ID"
// @Param limit query int false "Maximum number of posts"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed [get]
func listFeedPosts() {}

// createFeedPost documents POST /api/v1/feed.
// @Summary Create feed post
// @Tags feed
// @Accept json
// @Produce json
// @Param request body app.CreatePostInput true "Feed post payload"
// @Success 201 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed [post]
func createFeedPost() {}

// getFeedPost documents GET /api/v1/feed/{id}.
// @Summary Get feed post
// @Tags feed
// @Produce json
// @Param id path string true "Post ID"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed/{id} [get]
func getFeedPost() {}

// updateFeedPost documents PUT /api/v1/feed/{id}.
// @Summary Update own feed post
// @Tags feed
// @Accept json
// @Produce json
// @Param id path string true "Post ID"
// @Param request body app.UpdatePostInput true "Feed post update payload"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed/{id} [put]
func updateFeedPost() {}

// deleteFeedPost documents DELETE /api/v1/feed/{id}.
// @Summary Delete own feed post
// @Tags feed
// @Produce json
// @Param id path string true "Post ID"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed/{id} [delete]
func deleteFeedPost() {}

// toggleFeedPostReaction documents POST /api/v1/feed/{id}/react.
// @Summary Toggle feed post reaction
// @Tags feed
// @Produce json
// @Param id path string true "Post ID"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed/{id}/react [post]
func toggleFeedPostReaction() {}

// likeFeedPost documents POST /api/v1/feed/{id}/like.
// @Summary Like feed post
// @Tags feed
// @Produce json
// @Param id path string true "Post ID"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed/{id}/like [post]
func likeFeedPost() {}

// unlikeFeedPost documents DELETE /api/v1/feed/{id}/like.
// @Summary Unlike feed post
// @Tags feed
// @Produce json
// @Param id path string true "Post ID"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed/{id}/like [delete]
func unlikeFeedPost() {}

// hideFeedPost documents POST /api/v1/feed/{id}/hide.
// @Summary Hide feed post for current user
// @Tags feed
// @Produce json
// @Param id path string true "Post ID"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed/{id}/hide [post]
func hideFeedPost() {}

// reportFeedPost documents POST /api/v1/feed/{id}/report.
// @Summary Report feed post
// @Tags feed
// @Accept json
// @Produce json
// @Param id path string true "Post ID"
// @Param request body app.ReportPostInput true "Report payload"
// @Success 201 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed/{id}/report [post]
func reportFeedPost() {}

// listFeedPostComments documents GET /api/v1/feed/{id}/comments.
// @Summary List feed post comments
// @Tags feed
// @Produce json
// @Param id path string true "Post ID"
// @Param cursor query string false "Pagination cursor"
// @Param limit query int false "Maximum number of comments"
// @Success 200 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed/{id}/comments [get]
func listFeedPostComments() {}

// createFeedPostComment documents POST /api/v1/feed/{id}/comments.
// @Summary Create feed post comment
// @Tags feed
// @Accept json
// @Produce json
// @Param id path string true "Post ID"
// @Param request body app.CreateCommentInput true "Comment payload"
// @Success 201 {object} response.ApiResponse
// @Failure 400 {object} response.ApiResponse
// @Failure 401 {object} response.ApiResponse
// @Security BearerAuth
// @Router /api/v1/feed/{id}/comments [post]
func createFeedPostComment() {}
