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

// UserLookup is the only user-domain capability chat needs for conversation setup.
type UserLookup interface {
	GetUser(ctx context.Context, userID string) (userdomain.User, error)
}

type CreateConversationInput struct {
	ParticipantIDs []string `json:"participant_ids"`
}

type SendMessageInput struct {
	Body string `json:"body"`
}

type Service struct {
	repo       domain.Repository
	users      UserLookup
	publisher  messaging.Publisher
	timeSource func() time.Time
	idSource   func(prefix string) string
}

func NewService(repo domain.Repository, users UserLookup, publisher messaging.Publisher) *Service {
	return &Service{
		repo:      repo,
		users:     users,
		publisher: publisher,
		timeSource: func() time.Time {
			return time.Now().UTC()
		},
		idSource: func(_ string) string { return identity.NewUUID() },
	}
}

func (s *Service) CreateConversation(ctx context.Context, actorUserID string, input CreateConversationInput) (domain.Conversation, error) {
	if len(input.ParticipantIDs) == 0 {
		return domain.Conversation{}, errors.New("participant_ids is required")
	}

	participantSet := map[string]struct{}{actorUserID: {}}
	for _, participantID := range input.ParticipantIDs {
		participantID = strings.TrimSpace(participantID)
		if participantID == "" {
			continue
		}
		if _, err := s.users.GetUser(ctx, participantID); err != nil {
			return domain.Conversation{}, err
		}
		participantSet[participantID] = struct{}{}
	}

	participants := make([]string, 0, len(participantSet))
	for id := range participantSet {
		participants = append(participants, id)
	}

	conversation := domain.Conversation{
		ID:             s.idSource("conv"),
		ParticipantIDs: participants,
		CreatedAt:      s.timeSource(),
	}
	if err := s.repo.CreateConversation(ctx, conversation); err != nil {
		return domain.Conversation{}, err
	}

	return conversation, nil
}

func (s *Service) ListConversations(ctx context.Context, actorUserID string) ([]domain.Conversation, error) {
	return s.repo.ListConversations(ctx, actorUserID)
}

func (s *Service) ListMessages(ctx context.Context, actorUserID, conversationID string) ([]domain.Message, error) {
	conversation, err := s.repo.GetConversation(ctx, conversationID)
	if err != nil {
		return nil, err
	}
	if !contains(conversation.ParticipantIDs, actorUserID) {
		return nil, errors.New("conversation access denied")
	}

	return s.repo.ListMessages(ctx, conversationID)
}

func (s *Service) SendMessage(ctx context.Context, actorUserID, conversationID string, input SendMessageInput) (domain.Message, error) {
	if err := validate.Required(input.Body, "body"); err != nil {
		return domain.Message{}, err
	}

	conversation, err := s.repo.GetConversation(ctx, conversationID)
	if err != nil {
		return domain.Message{}, err
	}
	if !contains(conversation.ParticipantIDs, actorUserID) {
		return domain.Message{}, errors.New("conversation access denied")
	}

	message := domain.Message{
		ID:             s.idSource("msg"),
		ConversationID: conversationID,
		SenderUserID:   actorUserID,
		Body:           strings.TrimSpace(input.Body),
		CreatedAt:      s.timeSource(),
	}
	if err := s.repo.CreateMessage(ctx, message); err != nil {
		return domain.Message{}, err
	}

	_ = s.publisher.Publish(ctx, messaging.Event{
		Name:        "chat.message.sent",
		Version:     1,
		Aggregate:   "conversation",
		AggregateID: conversationID,
		Payload: map[string]any{
			"message_id": message.ID,
			"sender_id":  actorUserID,
		},
	})

	return message, nil
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
