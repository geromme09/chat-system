package app

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/geromme09/chat-system/internal/modules/feed/domain"
	"github.com/geromme09/chat-system/internal/platform/identity"
)

type MediaStorage interface {
	SaveFeedImageDataURL(ctx context.Context, dataURL string) (string, error)
}

type NotificationService interface {
	NotifyFeedPostComment(ctx context.Context, recipientUserID string, actor domain.Author, post domain.Post, comment domain.Comment) error
	NotifyFeedCommentReply(ctx context.Context, recipientUserID string, actor domain.Author, post domain.Post, comment domain.Comment, parentComment domain.Comment) error
}

type CreatePostInput struct {
	Caption      string `json:"caption" validate:"required"`
	ImageDataURL string `json:"image_data_url"`
}

type CreateCommentInput struct {
	Body            string `json:"body"`
	ParentCommentID string `json:"parent_comment_id"`
}

type Service struct {
	repo       domain.Repository
	storage    MediaStorage
	notifier   NotificationService
	timeSource func() time.Time
	idSource   func() string
}

func NewService(repo domain.Repository, storage MediaStorage, notifier NotificationService) *Service {
	return &Service{
		repo:     repo,
		storage:  storage,
		notifier: notifier,
		timeSource: func() time.Time {
			return time.Now().UTC()
		},
		idSource: identity.NewUUID,
	}
}

func (s *Service) GetPost(ctx context.Context, actorUserID, postID string) (domain.Post, error) {
	postID = strings.TrimSpace(postID)
	if postID == "" {
		return domain.Post{}, errors.New("post id is required")
	}

	return s.repo.GetPost(ctx, actorUserID, postID)
}

func (s *Service) ListPosts(ctx context.Context, actorUserID string, input domain.ListPostsInput) (domain.PostPage, error) {
	if input.Limit <= 0 {
		input.Limit = 20
	}
	if input.Limit > 50 {
		input.Limit = 50
	}

	if input.CursorCreatedAt == nil && strings.TrimSpace(input.Cursor) != "" {
		cursorCreatedAt, cursorID, err := decodePostCursor(strings.TrimSpace(input.Cursor))
		if err != nil {
			return domain.PostPage{}, err
		}
		input.CursorCreatedAt = cursorCreatedAt
		input.CursorID = cursorID
	}

	rows, err := s.repo.ListPosts(ctx, actorUserID, domain.ListPostsInput{
		AuthorUserID:    strings.TrimSpace(input.AuthorUserID),
		Limit:           input.Limit + 1,
		CursorCreatedAt: input.CursorCreatedAt,
		CursorID:        strings.TrimSpace(input.CursorID),
	})
	if err != nil {
		return domain.PostPage{}, err
	}

	page := domain.PostPage{
		Items: rows,
	}
	if len(rows) > input.Limit {
		last := rows[input.Limit-1]
		page.Items = rows[:input.Limit]
		page.NextCursor = encodePostCursor(last.CreatedAt, last.ID)
	}

	return page, nil
}

func (s *Service) CreatePost(ctx context.Context, author domain.Author, input CreatePostInput) (domain.Post, error) {
	caption := strings.TrimSpace(input.Caption)
	imageDataURL := strings.TrimSpace(input.ImageDataURL)

	if caption == "" {
		return domain.Post{}, errors.New("caption is required")
	}

	postType := domain.PostTypeText
	imageURL := ""
	if imageDataURL != "" {
		if !strings.HasPrefix(imageDataURL, "data:image/") {
			return domain.Post{}, errors.New("image_data_url must be a valid image data URL")
		}
		if s.storage == nil {
			return domain.Post{}, errors.New("media storage is not configured")
		}
		var err error
		imageURL, err = s.storage.SaveFeedImageDataURL(ctx, imageDataURL)
		if err != nil {
			return domain.Post{}, err
		}
		postType = domain.PostTypeImage
	}

	post := domain.Post{
		ID:        s.idSource(),
		Author:    author,
		Type:      postType,
		Caption:   caption,
		ImageURL:  imageURL,
		CreatedAt: s.timeSource(),
	}

	if err := s.repo.CreatePost(ctx, post, imageURL); err != nil {
		return domain.Post{}, err
	}

	return post, nil
}

func (s *Service) ToggleReaction(ctx context.Context, actorUserID, postID string) (domain.Post, error) {
	postID = strings.TrimSpace(postID)
	if postID == "" {
		return domain.Post{}, errors.New("post id is required")
	}

	return s.repo.ToggleReaction(ctx, postID, actorUserID, s.timeSource())
}

func (s *Service) ListComments(ctx context.Context, postID string, limit int) ([]domain.Comment, error) {
	postID = strings.TrimSpace(postID)
	if postID == "" {
		return nil, errors.New("post id is required")
	}
	if limit <= 0 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}

	return s.repo.ListComments(ctx, postID, limit)
}

func (s *Service) CreateComment(ctx context.Context, author domain.Author, postID string, input CreateCommentInput) (domain.Comment, error) {
	postID = strings.TrimSpace(postID)
	body := strings.TrimSpace(input.Body)
	if postID == "" {
		return domain.Comment{}, errors.New("post id is required")
	}
	if body == "" {
		return domain.Comment{}, errors.New("comment is required")
	}
	if len(body) > 500 {
		return domain.Comment{}, errors.New("comment is too long")
	}
	if _, err := s.repo.GetPost(ctx, author.UserID, postID); err != nil {
		return domain.Comment{}, err
	}

	post, err := s.repo.GetPost(ctx, author.UserID, postID)
	if err != nil {
		return domain.Comment{}, err
	}

	var parentComment domain.Comment

	parentCommentID := strings.TrimSpace(input.ParentCommentID)
	if parentCommentID != "" {
		parentComment, err = s.repo.GetComment(ctx, parentCommentID)
		if err != nil {
			return domain.Comment{}, err
		}
		if parentComment.PostID != postID {
			return domain.Comment{}, errors.New("reply must belong to the same post")
		}
		input.ParentCommentID = parentCommentID
	}

	comment := domain.Comment{
		ID:              s.idSource(),
		PostID:          postID,
		ParentCommentID: input.ParentCommentID,
		Author:          author,
		Body:            body,
		CreatedAt:       s.timeSource(),
	}
	if err := s.repo.CreateComment(ctx, comment); err != nil {
		return domain.Comment{}, err
	}

	if s.notifier != nil {
		if parentComment.ID != "" &&
			parentComment.Author.UserID != "" &&
			parentComment.Author.UserID != author.UserID {
			_ = s.notifier.NotifyFeedCommentReply(
				ctx,
				parentComment.Author.UserID,
				author,
				post,
				comment,
				parentComment,
			)
		}

		if parentComment.ID == "" &&
			post.Author.UserID != "" &&
			post.Author.UserID != author.UserID {
			_ = s.notifier.NotifyFeedPostComment(
				ctx,
				post.Author.UserID,
				author,
				post,
				comment,
			)
		}
	}

	return comment, nil
}

func encodePostCursor(createdAt time.Time, postID string) string {
	payload := fmt.Sprintf("%d|%s", createdAt.UTC().UnixNano(), postID)
	return base64.RawURLEncoding.EncodeToString([]byte(payload))
}

func decodePostCursor(cursor string) (*time.Time, string, error) {
	if cursor == "" {
		return nil, "", nil
	}

	raw, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return nil, "", errors.New("invalid cursor")
	}

	parts := strings.SplitN(string(raw), "|", 2)
	if len(parts) != 2 || strings.TrimSpace(parts[1]) == "" {
		return nil, "", errors.New("invalid cursor")
	}

	unixNano, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return nil, "", errors.New("invalid cursor")
	}

	value := time.Unix(0, unixNano).UTC()
	return &value, parts[1], nil
}
