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
	"github.com/geromme09/chat-system/internal/platform/storage"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
)

var tracer = otel.Tracer("feed-service")

type MediaStorage interface {
	SaveFeedImageDataURL(ctx context.Context, dataURL string) (storage.ObjectRef, error)
	PublicURL(ref storage.ObjectRef) string
	DeleteObject(ctx context.Context, ref storage.ObjectRef) error
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

type UpdatePostInput struct {
	Caption string `json:"caption"`
}

type ReportPostInput struct {
	Reason string `json:"reason"`
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
	ctx, span := tracer.Start(ctx, "feed.create_post")
	defer span.End()

	caption := strings.TrimSpace(input.Caption)
	imageDataURL := strings.TrimSpace(input.ImageDataURL)

	if caption == "" {
		return domain.Post{}, errors.New("caption is required")
	}

	postType := domain.PostTypeText
	imageURL := ""
	var imageRef storage.ObjectRef
	if imageDataURL != "" {
		if !strings.HasPrefix(imageDataURL, "data:image/") {
			return domain.Post{}, errors.New("image_data_url must be a valid image data URL")
		}
		if s.storage == nil {
			return domain.Post{}, errors.New("media storage is not configured")
		}
		_, storageSpan := tracer.Start(ctx, "feed.create_post.save_image")
		var err error
		imageRef, err = s.storage.SaveFeedImageDataURL(ctx, imageDataURL)
		storageSpan.SetAttributes(
			attribute.String("storage.bucket", imageRef.Bucket),
			attribute.String("storage.object_key", imageRef.ObjectKey),
		)
		storageSpan.End()
		if err != nil {
			return domain.Post{}, err
		}
		imageURL = s.storage.PublicURL(imageRef)
		postType = domain.PostTypeImage
	}

	post := domain.Post{
		ID:          s.idSource(),
		Author:      author,
		Type:        postType,
		Caption:     caption,
		ImageURL:    imageURL,
		ImageBucket: imageRef.Bucket,
		ImageKey:    imageRef.ObjectKey,
		ImageType:   imageRef.ContentType,
		CreatedAt:   s.timeSource(),
	}

	_, createPostSpan := tracer.Start(ctx, "feed.create_post.persist_post")
	if err := s.repo.CreatePost(ctx, post); err != nil {
		createPostSpan.End()
		return domain.Post{}, err
	}
	createPostSpan.End()
	span.SetAttributes(
		attribute.String("post.id", post.ID),
		attribute.String("post.type", string(post.Type)),
	)

	return post, nil
}

func (s *Service) UpdatePost(ctx context.Context, actorUserID, postID string, input UpdatePostInput) (domain.Post, error) {
	postID = strings.TrimSpace(postID)
	caption := strings.TrimSpace(input.Caption)
	if postID == "" {
		return domain.Post{}, errors.New("post id is required")
	}
	if caption == "" {
		return domain.Post{}, errors.New("caption is required")
	}

	return s.repo.UpdatePost(ctx, actorUserID, postID, caption)
}

func (s *Service) DeletePost(ctx context.Context, actorUserID, postID string) error {
	postID = strings.TrimSpace(postID)
	if postID == "" {
		return errors.New("post id is required")
	}

	post, err := s.repo.GetPost(ctx, actorUserID, postID)
	if err != nil {
		return err
	}
	if err := s.repo.DeletePost(ctx, actorUserID, postID); err != nil {
		return err
	}
	if s.storage != nil {
		_ = s.storage.DeleteObject(ctx, storage.ObjectRef{
			Bucket:    post.ImageBucket,
			ObjectKey: post.ImageKey,
		})
	}
	return nil
}

func (s *Service) HidePost(ctx context.Context, actorUserID, postID string) error {
	postID = strings.TrimSpace(postID)
	if postID == "" {
		return errors.New("post id is required")
	}

	if _, err := s.repo.GetPost(ctx, actorUserID, postID); err != nil {
		return err
	}

	return s.repo.HidePost(ctx, postID, actorUserID, s.timeSource())
}

func (s *Service) ReportPost(ctx context.Context, actorUserID, postID string, input ReportPostInput) (domain.PostReport, error) {
	postID = strings.TrimSpace(postID)
	if postID == "" {
		return domain.PostReport{}, errors.New("post id is required")
	}

	if _, err := s.repo.GetPost(ctx, actorUserID, postID); err != nil {
		return domain.PostReport{}, err
	}

	report := domain.PostReport{
		ID:             s.idSource(),
		PostID:         postID,
		ReporterUserID: actorUserID,
		Reason:         strings.TrimSpace(input.Reason),
		Status:         "pending",
		CreatedAt:      s.timeSource(),
	}
	if report.Reason == "" {
		report.Reason = "unspecified"
	}

	if err := s.repo.ReportPost(ctx, report); err != nil {
		return domain.PostReport{}, err
	}

	return report, nil
}

func (s *Service) ToggleReaction(ctx context.Context, actorUserID, postID string) (domain.Post, error) {
	postID = strings.TrimSpace(postID)
	if postID == "" {
		return domain.Post{}, errors.New("post id is required")
	}

	return s.repo.ToggleReaction(ctx, postID, actorUserID, s.timeSource())
}

func (s *Service) SetReaction(ctx context.Context, actorUserID, postID string, reacted bool) (domain.Post, error) {
	postID = strings.TrimSpace(postID)
	if postID == "" {
		return domain.Post{}, errors.New("post id is required")
	}

	return s.repo.SetReaction(ctx, postID, actorUserID, reacted, s.timeSource())
}

func (s *Service) ListComments(ctx context.Context, postID string, input domain.ListCommentsInput) (domain.CommentPage, error) {
	postID = strings.TrimSpace(postID)
	if postID == "" {
		return domain.CommentPage{}, errors.New("post id is required")
	}
	if input.Limit <= 0 {
		input.Limit = 20
	}
	if input.Limit > 50 {
		input.Limit = 50
	}

	if input.CursorCreatedAt == nil && strings.TrimSpace(input.Cursor) != "" {
		cursorCreatedAt, cursorID, err := decodeCursor(strings.TrimSpace(input.Cursor))
		if err != nil {
			return domain.CommentPage{}, err
		}
		input.CursorCreatedAt = cursorCreatedAt
		input.CursorID = cursorID
	}

	rows, err := s.repo.ListComments(ctx, postID, domain.ListCommentsInput{
		Limit:           input.Limit + 1,
		CursorCreatedAt: input.CursorCreatedAt,
		CursorID:        strings.TrimSpace(input.CursorID),
	})
	if err != nil {
		return domain.CommentPage{}, err
	}

	page := domain.CommentPage{
		Items: rows,
	}
	if len(rows) > input.Limit {
		last := rows[input.Limit-1]
		page.Items = rows[:input.Limit]
		page.NextCursor = encodeCursor(last.CreatedAt, last.ID)
	}

	return page, nil
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
	return encodeCursor(createdAt, postID)
}

func decodePostCursor(cursor string) (*time.Time, string, error) {
	return decodeCursor(cursor)
}

func encodeCursor(createdAt time.Time, id string) string {
	payload := fmt.Sprintf("%d|%s", createdAt.UTC().UnixNano(), id)
	return base64.RawURLEncoding.EncodeToString([]byte(payload))
}

func decodeCursor(cursor string) (*time.Time, string, error) {
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
