package domain

import (
	"context"
	"time"
)

const (
	PostTypeText  = "text"
	PostTypeImage = "image"
)

type Post struct {
	ID            string    `json:"id"`
	Author        Author    `json:"author"`
	Type          string    `json:"type"`
	Caption       string    `json:"caption"`
	ImageURL      string    `json:"image_url"`
	ReactionCount int64     `json:"reaction_count"`
	CommentCount  int64     `json:"comment_count"`
	ReactedByMe   bool      `json:"reacted_by_me"`
	CreatedAt     time.Time `json:"created_at"`
}

type Author struct {
	UserID           string `json:"user_id"`
	Username         string `json:"username"`
	DisplayName      string `json:"display_name"`
	AvatarURL        string `json:"avatar_url"`
	City             string `json:"city"`
	ConnectionStatus string `json:"connection_status"`
}

type Comment struct {
	ID              string    `json:"id"`
	PostID          string    `json:"post_id"`
	ParentCommentID string    `json:"parent_comment_id,omitempty"`
	Author          Author    `json:"author"`
	Body            string    `json:"body"`
	CreatedAt       time.Time `json:"created_at"`
}

type ListPostsInput struct {
	Cursor          string
	AuthorUserID    string
	Limit           int
	CursorCreatedAt *time.Time
	CursorID        string
}

type PostPage struct {
	Items      []Post `json:"items"`
	NextCursor string `json:"next_cursor,omitempty"`
}

type Repository interface {
	CreatePost(ctx context.Context, post Post, imageURL string) error
	ListPosts(ctx context.Context, actorUserID string, input ListPostsInput) ([]Post, error)
	GetPost(ctx context.Context, actorUserID, postID string) (Post, error)
	ToggleReaction(ctx context.Context, postID, userID string, reactedAt time.Time) (Post, error)
	CreateComment(ctx context.Context, comment Comment) error
	GetComment(ctx context.Context, commentID string) (Comment, error)
	ListComments(ctx context.Context, postID string, limit int) ([]Comment, error)
}
