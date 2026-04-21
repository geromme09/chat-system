package infra

import (
	"context"
	"errors"
	"sync"

	"github.com/geromme09/chat-system/internal/modules/user/domain"
)

type MemoryRepository struct {
	mu           sync.RWMutex
	usersByID    map[string]domain.User
	usersByEmail map[string]string
	profiles     map[string]domain.Profile
}

func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{
		usersByID:    map[string]domain.User{},
		usersByEmail: map[string]string{},
		profiles:     map[string]domain.Profile{},
	}
}

func (r *MemoryRepository) CreateUser(_ context.Context, user domain.User) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.usersByEmail[user.Email]; exists {
		return errors.New("email already exists")
	}

	r.usersByID[user.ID] = user
	r.usersByEmail[user.Email] = user.ID
	return nil
}

func (r *MemoryRepository) FindUserByEmail(_ context.Context, email string) (domain.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	id, ok := r.usersByEmail[email]
	if !ok {
		return domain.User{}, errors.New("user not found")
	}

	return r.usersByID[id], nil
}

func (r *MemoryRepository) GetUser(_ context.Context, userID string) (domain.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	user, ok := r.usersByID[userID]
	if !ok {
		return domain.User{}, errors.New("user not found")
	}

	return user, nil
}

func (r *MemoryRepository) UpsertProfile(_ context.Context, profile domain.Profile) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.profiles[profile.UserID] = profile
	return nil
}

func (r *MemoryRepository) GetProfile(_ context.Context, userID string) (domain.Profile, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	profile, ok := r.profiles[userID]
	if !ok {
		return domain.Profile{}, errors.New("profile not found")
	}

	return profile, nil
}
