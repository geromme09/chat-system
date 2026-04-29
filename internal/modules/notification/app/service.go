package app

import (
	"context"
	"strings"
	"time"

	feeddomain "github.com/geromme09/chat-system/internal/modules/feed/domain"
	notificationdomain "github.com/geromme09/chat-system/internal/modules/notification/domain"
	userdomain "github.com/geromme09/chat-system/internal/modules/user/domain"
	"github.com/geromme09/chat-system/internal/platform/identity"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
)

var tracer = otel.Tracer("notification-service")

type Channel interface {
	Deliver(ctx context.Context, notification notificationdomain.Notification) error
}

type ChannelFactory interface {
	Build(notification notificationdomain.Notification) []Channel
}

type StaticChannelFactory struct {
	channels []Channel
}

func NewStaticChannelFactory(channels ...Channel) *StaticChannelFactory {
	return &StaticChannelFactory{
		channels: channels,
	}
}

func (f *StaticChannelFactory) Build(notification notificationdomain.Notification) []Channel {
	return append([]Channel(nil), f.channels...)
}

type Service struct {
	repo       notificationdomain.Repository
	factory    ChannelFactory
	timeSource func() time.Time
	idSource   func() string
}

type ListNotificationsInput struct {
	Page  int
	Limit int
}

func NewService(repo notificationdomain.Repository, factory ChannelFactory) *Service {
	return &Service{
		repo:    repo,
		factory: factory,
		timeSource: func() time.Time {
			return time.Now().UTC()
		},
		idSource: identity.NewUUID,
	}
}

func (s *Service) ListNotifications(ctx context.Context, userID string, input ListNotificationsInput) (notificationdomain.Page, error) {
	page := input.Page
	if page < 1 {
		page = 1
	}

	limit := input.Limit
	switch {
	case limit <= 0:
		limit = 15
	case limit > 50:
		limit = 50
	}

	offset := (page - 1) * limit
	rows, err := s.repo.ListByUser(ctx, userID, offset, limit+1)
	if err != nil {
		return notificationdomain.Page{}, err
	}

	result := notificationdomain.Page{
		Items: rows,
		Page:  page,
		Limit: limit,
	}
	if len(rows) > limit {
		nextPage := page + 1
		result.NextPage = &nextPage
		result.Items = rows[:limit]
	}

	return result, nil
}

func (s *Service) MarkAllRead(ctx context.Context, userID string) error {
	return s.repo.MarkAllRead(ctx, userID, s.timeSource())
}

func (s *Service) MarkRead(ctx context.Context, userID, notificationID string) error {
	return s.repo.MarkRead(ctx, userID, notificationID, s.timeSource())
}

func (s *Service) NotifyFriendRequestCreated(ctx context.Context, friendRequest userdomain.FriendRequest) error {
	ctx, span := tracer.Start(ctx, "notification.friend_request_created")
	defer span.End()
	span.SetAttributes(
		attribute.String("notification.user_id", friendRequest.AddresseeID),
		attribute.String("friend_request.id", friendRequest.ID),
	)
	return s.createAndDispatch(ctx, buildNotification(
		s.idSource(),
		s.timeSource(),
		friendRequest.AddresseeID,
		notificationdomain.TypeFriendRequestReceived,
		primaryLabel(friendRequest.Requester),
		"Friend Request",
		friendRequestData(friendRequest),
	))
}

func (s *Service) NotifyFriendRequestResponded(ctx context.Context, friendRequest userdomain.FriendRequest) error {
	if friendRequest.Status != userdomain.FriendRequestStatusAccepted {
		return nil
	}

	ctx, span := tracer.Start(ctx, "notification.friend_request_responded")
	defer span.End()
	span.SetAttributes(
		attribute.String("notification.user_id", friendRequest.RequesterID),
		attribute.String("friend_request.id", friendRequest.ID),
	)
	return s.createAndDispatch(ctx, buildNotification(
		s.idSource(),
		s.timeSource(),
		friendRequest.RequesterID,
		notificationdomain.TypeFriendRequestAccepted,
		primaryLabel(friendRequest.Addressee),
		"Accepted your request",
		friendRequestData(friendRequest),
	))
}

func (s *Service) NotifyFeedPostComment(ctx context.Context, recipientUserID string, actor feeddomain.Author, post feeddomain.Post, comment feeddomain.Comment) error {
	if strings.TrimSpace(recipientUserID) == "" {
		return nil
	}

	ctx, span := tracer.Start(ctx, "notification.feed_post_comment")
	defer span.End()
	span.SetAttributes(
		attribute.String("notification.user_id", recipientUserID),
		attribute.String("post.id", post.ID),
		attribute.String("comment.id", comment.ID),
	)
	return s.createAndDispatch(ctx, buildNotification(
		s.idSource(),
		s.timeSource(),
		recipientUserID,
		notificationdomain.TypeFeedPostComment,
		primaryFeedLabel(actor),
		"Commented on your post",
		feedPostCommentData(actor, post, comment),
	))
}

func (s *Service) NotifyFeedCommentReply(ctx context.Context, recipientUserID string, actor feeddomain.Author, post feeddomain.Post, comment feeddomain.Comment, parentComment feeddomain.Comment) error {
	if strings.TrimSpace(recipientUserID) == "" {
		return nil
	}

	ctx, span := tracer.Start(ctx, "notification.feed_comment_reply")
	defer span.End()
	span.SetAttributes(
		attribute.String("notification.user_id", recipientUserID),
		attribute.String("post.id", post.ID),
		attribute.String("comment.id", comment.ID),
		attribute.String("parent_comment.id", parentComment.ID),
	)
	return s.createAndDispatch(ctx, buildNotification(
		s.idSource(),
		s.timeSource(),
		recipientUserID,
		notificationdomain.TypeFeedCommentReply,
		primaryFeedLabel(actor),
		"Replied to your comment",
		feedCommentReplyData(actor, post, comment, parentComment),
	))
}

func (s *Service) createAndDispatch(ctx context.Context, notification notificationdomain.Notification) error {
	ctx, span := tracer.Start(ctx, "notification.create_and_dispatch")
	defer span.End()
	span.SetAttributes(
		attribute.String("notification.id", notification.ID),
		attribute.String("notification.type", notification.Type),
		attribute.String("notification.user_id", notification.UserID),
	)

	_, createSpan := tracer.Start(ctx, "notification.persist")
	created, err := s.repo.Create(ctx, notification)
	createSpan.End()
	if err != nil {
		return err
	}

	for _, channel := range s.factory.Build(created) {
		_, deliverSpan := tracer.Start(ctx, "notification.deliver_channel")
		_ = channel.Deliver(ctx, created)
		deliverSpan.End()
	}

	return nil
}

func primaryLabel(card userdomain.UserCard) string {
	if card.DisplayName != "" {
		return card.DisplayName
	}
	return card.Username
}

func primaryFeedLabel(author feeddomain.Author) string {
	if author.DisplayName != "" {
		return author.DisplayName
	}
	return author.Username
}

func buildNotification(id string, createdAt time.Time, userID, notificationType, title, body string, data map[string]any) notificationdomain.Notification {
	return notificationdomain.Notification{
		ID:        id,
		UserID:    userID,
		Type:      notificationType,
		Title:     title,
		Body:      body,
		Data:      data,
		CreatedAt: createdAt,
	}
}

func friendRequestData(friendRequest userdomain.FriendRequest) map[string]any {
	return map[string]any{
		"friend_request": map[string]any{
			"id":                friendRequest.ID,
			"requester_user_id": friendRequest.RequesterID,
			"addressee_user_id": friendRequest.AddresseeID,
			"status":            friendRequest.Status,
			"created_at":        friendRequest.CreatedAt,
			"updated_at":        friendRequest.UpdatedAt,
			"requester": map[string]any{
				"user_id":      friendRequest.Requester.UserID,
				"username":     friendRequest.Requester.Username,
				"display_name": friendRequest.Requester.DisplayName,
				"avatar_url":   friendRequest.Requester.AvatarURL,
				"city":         friendRequest.Requester.City,
			},
			"addressee": map[string]any{
				"user_id":      friendRequest.Addressee.UserID,
				"username":     friendRequest.Addressee.Username,
				"display_name": friendRequest.Addressee.DisplayName,
				"avatar_url":   friendRequest.Addressee.AvatarURL,
				"city":         friendRequest.Addressee.City,
			},
		},
	}
}

func feedPostCommentData(actor feeddomain.Author, post feeddomain.Post, comment feeddomain.Comment) map[string]any {
	return map[string]any{
		"feed_comment": map[string]any{
			"post_id":      post.ID,
			"comment_id":   comment.ID,
			"post_caption": post.Caption,
			"comment_body": comment.Body,
			"author": map[string]any{
				"user_id":      actor.UserID,
				"username":     actor.Username,
				"display_name": actor.DisplayName,
				"avatar_url":   actor.AvatarURL,
				"city":         actor.City,
			},
		},
	}
}

func feedCommentReplyData(actor feeddomain.Author, post feeddomain.Post, comment feeddomain.Comment, parentComment feeddomain.Comment) map[string]any {
	return map[string]any{
		"feed_reply": map[string]any{
			"post_id":           post.ID,
			"comment_id":        comment.ID,
			"parent_comment_id": parentComment.ID,
			"post_caption":      post.Caption,
			"comment_body":      comment.Body,
			"parent_body":       parentComment.Body,
			"author": map[string]any{
				"user_id":      actor.UserID,
				"username":     actor.Username,
				"display_name": actor.DisplayName,
				"avatar_url":   actor.AvatarURL,
				"city":         actor.City,
			},
		},
	}
}
