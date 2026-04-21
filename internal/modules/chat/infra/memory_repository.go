package infra

import (
	"context"
	"errors"
	"slices"
	"sync"

	"github.com/geromme09/chat-system/internal/modules/chat/domain"
)

type MemoryRepository struct {
	mu            sync.RWMutex
	conversations map[string]domain.Conversation
	messages      map[string][]domain.Message
}

func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{
		conversations: map[string]domain.Conversation{},
		messages:      map[string][]domain.Message{},
	}
}

func (r *MemoryRepository) CreateConversation(_ context.Context, conversation domain.Conversation) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.conversations[conversation.ID] = conversation
	return nil
}

func (r *MemoryRepository) ListConversations(_ context.Context, userID string) ([]domain.Conversation, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	conversations := make([]domain.Conversation, 0)
	for _, conversation := range r.conversations {
		if slices.Contains(conversation.ParticipantIDs, userID) {
			conversations = append(conversations, conversation)
		}
	}

	return conversations, nil
}

func (r *MemoryRepository) GetConversation(_ context.Context, conversationID string) (domain.Conversation, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	conversation, ok := r.conversations[conversationID]
	if !ok {
		return domain.Conversation{}, errors.New("conversation not found")
	}

	return conversation, nil
}

func (r *MemoryRepository) CreateMessage(_ context.Context, message domain.Message) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.messages[message.ConversationID] = append(r.messages[message.ConversationID], message)
	return nil
}

func (r *MemoryRepository) ListMessages(_ context.Context, conversationID string) ([]domain.Message, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	return append([]domain.Message{}, r.messages[conversationID]...), nil
}
