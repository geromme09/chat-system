package app

import (
	"context"
	"time"

	notificationdomain "github.com/geromme09/chat-system/internal/modules/notification/domain"
	userdomain "github.com/geromme09/chat-system/internal/modules/user/domain"
	"github.com/geromme09/chat-system/internal/platform/identity"
)

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
	return s.createAndDispatch(ctx, notificationdomain.Notification{
		ID:        s.idSource(),
		UserID:    friendRequest.AddresseeID,
		Type:      notificationdomain.TypeFriendRequestReceived,
		Title:     primaryLabel(friendRequest.Requester),
		Body:      "Friend Request",
		Data:      friendRequestData(friendRequest),
		CreatedAt: s.timeSource(),
	})
}

func (s *Service) NotifyFriendRequestResponded(ctx context.Context, friendRequest userdomain.FriendRequest) error {
	if friendRequest.Status != userdomain.FriendRequestStatusAccepted {
		return nil
	}

	return s.createAndDispatch(ctx, notificationdomain.Notification{
		ID:        s.idSource(),
		UserID:    friendRequest.RequesterID,
		Type:      notificationdomain.TypeFriendRequestAccepted,
		Title:     primaryLabel(friendRequest.Addressee),
		Body:      "Accepted your request",
		Data:      friendRequestData(friendRequest),
		CreatedAt: s.timeSource(),
	})
}

func (s *Service) createAndDispatch(ctx context.Context, notification notificationdomain.Notification) error {
	created, err := s.repo.Create(ctx, notification)
	if err != nil {
		return err
	}

	for _, channel := range s.factory.Build(created) {
		_ = channel.Deliver(ctx, created)
	}

	return nil
}

func primaryLabel(card userdomain.UserCard) string {
	if card.DisplayName != "" {
		return card.DisplayName
	}
	return card.Username
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
