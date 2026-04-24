package http

import (
	"context"
	"errors"
	"strconv"
	"strings"

	feedapp "github.com/geromme09/chat-system/internal/modules/feed/app"
	feeddomain "github.com/geromme09/chat-system/internal/modules/feed/domain"
	userapp "github.com/geromme09/chat-system/internal/modules/user/app"
	"github.com/geromme09/chat-system/internal/platform/httpx"
	"github.com/geromme09/chat-system/internal/platform/response"
)

type Handler struct {
	service     *feedapp.Service
	userService userProfileReader
}

type userProfileReader interface {
	GetMe(ctx context.Context, userID string) (userapp.AuthResult, error)
}

func NewHandler(service *feedapp.Service, userService userProfileReader) *Handler {
	return &Handler{
		service:     service,
		userService: userService,
	}
}

func (h *Handler) Serve(ctx httpx.Context) response.ApiResponse {
	userID, ok := ctx.UserID()
	if !ok {
		return response.Unauthorized(errors.New("missing user context"))
	}

	postID, action := parseFeedPath(ctx.Request.URL.Path)

	switch {
	case ctx.Request.Method == "GET" && postID == "" && action == "":
		limit, _ := strconv.Atoi(ctx.Query("limit"))
		posts, err := h.service.ListPosts(ctx.Request.Context(), userID, feeddomain.ListPostsInput{
			Cursor:       ctx.Query("cursor"),
			AuthorUserID: ctx.Query("author_user_id"),
			Limit:        limit,
		})
		if err != nil {
			return response.BadRequest(err)
		}
		return response.Ok(posts, nil)
	case ctx.Request.Method == "GET" && postID != "" && action == "":
		post, err := h.service.GetPost(ctx.Request.Context(), userID, postID)
		if err != nil {
			return response.BadRequest(err)
		}
		return response.Ok(post, nil)
	case ctx.Request.Method == "POST" && postID == "" && action == "":
		var input feedapp.CreatePostInput
		if err := ctx.DecodeJSON(&input); err != nil {
			return response.BadRequest(errors.New("invalid request body"))
		}

		me, err := h.userService.GetMe(ctx.Request.Context(), userID)
		if err != nil {
			return response.BadRequest(err)
		}

		post, err := h.service.CreatePost(ctx.Request.Context(), feeddomain.Author{
			UserID:      me.User.ID,
			Username:    me.User.Username,
			DisplayName: me.Profile.DisplayName,
			AvatarURL:   me.Profile.AvatarURL,
			City:        me.Profile.City,
		}, input)
		if err != nil {
			return response.BadRequest(err)
		}

		return response.Created(post)
	case ctx.Request.Method == "POST" && postID != "" && action == "react":
		post, err := h.service.ToggleReaction(ctx.Request.Context(), userID, postID)
		if err != nil {
			return response.BadRequest(err)
		}
		return response.Ok(post, nil)
	case ctx.Request.Method == "GET" && postID != "" && action == "comments":
		limit, _ := strconv.Atoi(ctx.Query("limit"))
		comments, err := h.service.ListComments(ctx.Request.Context(), postID, limit)
		if err != nil {
			return response.BadRequest(err)
		}
		return response.Ok(comments, nil)
	case ctx.Request.Method == "POST" && postID != "" && action == "comments":
		var input feedapp.CreateCommentInput
		if err := ctx.DecodeJSON(&input); err != nil {
			return response.BadRequest(errors.New("invalid request body"))
		}

		me, err := h.userService.GetMe(ctx.Request.Context(), userID)
		if err != nil {
			return response.BadRequest(err)
		}

		comment, err := h.service.CreateComment(ctx.Request.Context(), feeddomain.Author{
			UserID:      me.User.ID,
			Username:    me.User.Username,
			DisplayName: me.Profile.DisplayName,
			AvatarURL:   me.Profile.AvatarURL,
			City:        me.Profile.City,
		}, postID, input)
		if err != nil {
			return response.BadRequest(err)
		}
		return response.Created(comment)
	default:
		return response.MethodNotAllowed()
	}
}

func parseFeedPath(path string) (postID string, action string) {
	path = strings.TrimPrefix(path, "/api/v1/feed")
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) == 1 && parts[0] == "" {
		return "", ""
	}
	if len(parts) == 1 {
		return parts[0], ""
	}
	if len(parts) != 2 {
		return "", "invalid"
	}
	return parts[0], parts[1]
}
