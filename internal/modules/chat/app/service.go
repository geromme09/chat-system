package app

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/geromme09/chat-system/internal/modules/chat/domain"
	userdomain "github.com/geromme09/chat-system/internal/modules/user/domain"
	"github.com/geromme09/chat-system/internal/platform/identity"
	"github.com/geromme09/chat-system/internal/platform/messaging"
	"github.com/geromme09/chat-system/internal/platform/validate"
)

var errConversationAccessDenied = errors.New("conversation access denied")

type UserLookup interface {
	GetUser(ctx context.Context, userID string) (userdomain.User, error)
	GetFriendshipBetween(ctx context.Context, userAID, userBID string) (userdomain.FriendRequest, error)
}

type RealtimeNotifier interface {
	NotifyMessageCreated(ctx context.Context, conversation domain.Conversation, message domain.Message) error
	IsUserOnline(userID string) bool
}

type CreateConversationInput struct {
	ParticipantIDs []string `json:"participant_ids" validate:"required"`
}

type SendMessageInput struct {
	Body string `json:"body" validate:"required"`
}

type Service struct {
	repo       domain.Repository
	users      UserLookup
	publisher  messaging.Publisher
	notifier   RealtimeNotifier
	timeSource func() time.Time
	idSource   func(prefix string) string
}

func NewService(repo domain.Repository, users UserLookup, publisher messaging.Publisher, notifier RealtimeNotifier) *Service {
	return &Service{
		repo:      repo,
		users:     users,
		publisher: publisher,
		notifier:  notifier,
		timeSource: func() time.Time {
			return time.Now().UTC()
		},
		idSource: func(_ string) string { return identity.NewUUID() },
	}
}

func (s *Service) CreateConversation(ctx context.Context, actorUserID string, input CreateConversationInput) (domain.Conversation, error) {
	if err := validate.Struct(input); err != nil {
		return domain.Conversation{}, err
	}

	participantIDs := make([]string, 0, len(input.ParticipantIDs))
	participantSet := map[string]struct{}{}
	for _, participantID := range input.ParticipantIDs {
		participantID = strings.TrimSpace(participantID)
		if participantID == "" || participantID == actorUserID {
			continue
		}
		if _, exists := participantSet[participantID]; exists {
			continue
		}
		if _, err := s.users.GetUser(ctx, participantID); err != nil {
			return domain.Conversation{}, err
		}
		participantSet[participantID] = struct{}{}
		participantIDs = append(participantIDs, participantID)
	}

	if len(participantIDs) != domain.DirectConversationParticipantCount-1 {
		return domain.Conversation{}, errors.New("chat currently supports one accepted friend at a time")
	}

	friendID := participantIDs[0]
	friendship, err := s.users.GetFriendshipBetween(ctx, actorUserID, friendID)
	if err != nil {
		return domain.Conversation{}, err
	}
	if friendship.Status != userdomain.FriendRequestStatusAccepted {
		return domain.Conversation{}, errors.New("conversation requires an accepted friendship")
	}

	if existing, err := s.repo.FindDirectConversation(ctx, actorUserID, friendID); err == nil {
		return existing, nil
	}

	conversation := domain.Conversation{
		ID:             s.idSource("conv"),
		ParticipantIDs: []string{actorUserID, friendID},
		CreatedAt:      s.timeSource(),
	}
	if err := s.repo.CreateConversation(ctx, conversation); err != nil {
		return domain.Conversation{}, err
	}

	return s.repo.GetConversation(ctx, conversation.ID)
}

func (s *Service) EnsureFriendConnection(ctx context.Context, requesterUserID, addresseeUserID string) error {
	conversation, err := s.CreateConversation(ctx, requesterUserID, CreateConversationInput{
		ParticipantIDs: []string{addresseeUserID},
	})
	if err != nil {
		return err
	}

	messages, err := s.repo.ListMessages(ctx, conversation.ID, requesterUserID)
	if err != nil {
		return err
	}
	if len(messages) > 0 {
		return nil
	}

	message := domain.Message{
		ID:             s.idSource("msg"),
		ConversationID: conversation.ID,
		SenderUserID:   addresseeUserID,
		Body:           domain.SystemConnectionMessageBody,
		CreatedAt:      s.timeSource(),
	}
	if err := s.repo.CreateMessage(ctx, message); err != nil {
		return err
	}

	_ = s.publisher.Publish(ctx, messaging.Event{
		Name:        domain.EventMessageCreated,
		Version:     1,
		Aggregate:   domain.AggregateConversation,
		AggregateID: conversation.ID,
		Payload: map[string]any{
			domain.EventPayloadMessage: message,
		},
	})

	if s.notifier != nil {
		_ = s.notifier.NotifyMessageCreated(ctx, conversation, message)
	}

	return nil
}

func (s *Service) ListConversations(ctx context.Context, actorUserID string) ([]domain.Conversation, error) {
	conversations, err := s.repo.ListConversations(ctx, actorUserID)
	if err != nil {
		return nil, err
	}

	for index := range conversations {
		conversations[index].OtherParticipant.IsOnline = s.notifier != nil &&
			s.notifier.IsUserOnline(conversations[index].OtherParticipant.UserID)
	}

	return conversations, nil
}

func (s *Service) ListMessages(ctx context.Context, actorUserID, conversationID string) ([]domain.Message, error) {
	conversation, err := s.getAccessibleConversation(ctx, actorUserID, conversationID)
	if err != nil {
		return nil, err
	}

	return s.repo.ListMessages(ctx, conversation.ID, actorUserID)
}

func (s *Service) SendMessage(ctx context.Context, actorUserID, conversationID string, input SendMessageInput) (domain.Message, error) {
	if err := validate.Struct(input); err != nil {
		return domain.Message{}, err
	}

	body := strings.TrimSpace(input.Body)
	if body == "" {
		return domain.Message{}, errors.New("message body is required")
	}
	if len(body) > domain.MaxMessageBodyLength {
		return domain.Message{}, errors.New("message body is too long")
	}

	conversation, err := s.getAccessibleConversation(ctx, actorUserID, conversationID)
	if err != nil {
		return domain.Message{}, err
	}

	message := domain.Message{
		ID:             s.idSource("msg"),
		ConversationID: conversationID,
		SenderUserID:   actorUserID,
		Body:           body,
		CreatedAt:      s.timeSource(),
	}
	if err := s.repo.CreateMessage(ctx, message); err != nil {
		return domain.Message{}, err
	}

	_ = s.publisher.Publish(ctx, messaging.Event{
		Name:        domain.EventMessageCreated,
		Version:     1,
		Aggregate:   domain.AggregateConversation,
		AggregateID: conversationID,
		Payload: map[string]any{
			domain.EventPayloadMessage: message,
		},
	})

	if s.notifier != nil {
		_ = s.notifier.NotifyMessageCreated(ctx, conversation, message)
	}

	return message, nil
}

func (s *Service) MarkConversationRead(ctx context.Context, actorUserID, conversationID string) (domain.ConversationReadResult, error) {
	conversation, err := s.getAccessibleConversation(ctx, actorUserID, conversationID)
	if err != nil {
		return domain.ConversationReadResult{}, err
	}

	markedCount, err := s.repo.MarkConversationRead(ctx, conversation.ID, actorUserID, s.timeSource())
	if err != nil {
		return domain.ConversationReadResult{}, err
	}

	return domain.ConversationReadResult{
		ConversationID: conversationID,
		MarkedCount:    markedCount,
	}, nil
}

func (s *Service) GetUnreadCount(ctx context.Context, actorUserID string) (domain.UnreadCount, error) {
	total, err := s.repo.GetUnreadCount(ctx, actorUserID)
	if err != nil {
		return domain.UnreadCount{}, err
	}

	return domain.UnreadCount{Total: total}, nil
}

func (s *Service) getAccessibleConversation(ctx context.Context, actorUserID, conversationID string) (domain.Conversation, error) {
	conversation, err := s.repo.GetConversation(ctx, conversationID)
	if err != nil {
		return domain.Conversation{}, err
	}
	if !contains(conversation.ParticipantIDs, actorUserID) {
		return domain.Conversation{}, errConversationAccessDenied
	}

	return conversation, nil
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
