package integration

import (
	"context"
	"errors"
	"testing"
	"time"

	chatapp "github.com/geromme09/chat-system/internal/modules/chat/app"
	chatinfra "github.com/geromme09/chat-system/internal/modules/chat/infra"
	userapp "github.com/geromme09/chat-system/internal/modules/user/app"
	userdomain "github.com/geromme09/chat-system/internal/modules/user/domain"
	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/messaging"
	"github.com/geromme09/chat-system/internal/platform/storage"
)

func TestSignUpLoginAndChatFlow(t *testing.T) {
	userRepo := newUserRepositoryStub()
	chatRepo := chatinfra.NewMemoryRepository()
	userService := userapp.NewService(userRepo, auth.PasswordHasher{}, auth.NewTokenManager("test-secret"), storage.NewService("https://cdn.test"))
	chatService := chatapp.NewService(chatRepo, userRepo, messaging.NoopPublisher{})

	ctx := context.Background()

	alice, err := userService.SignUp(ctx, userapp.SignUpInput{
		Email:          "alice@example.com",
		Password:       "password123",
		DisplayName:    "Alice",
		AvatarFileName: "alice.png",
		City:           "Makati",
		Country:        "Philippines",
	})
	if err != nil {
		t.Fatalf("signup alice: %v", err)
	}

	bob, err := userService.SignUp(ctx, userapp.SignUpInput{
		Email:          "bob@example.com",
		Password:       "password123",
		DisplayName:    "Bob",
		AvatarFileName: "bob.png",
		City:           "Taguig",
		Country:        "Philippines",
	})
	if err != nil {
		t.Fatalf("signup bob: %v", err)
	}

	if _, err := userService.Login(ctx, userapp.LoginInput{
		Email:    "alice@example.com",
		Password: "password123",
	}); err != nil {
		t.Fatalf("login alice: %v", err)
	}

	conversation, err := chatService.CreateConversation(ctx, alice.User.ID, chatapp.CreateConversationInput{
		ParticipantIDs: []string{bob.User.ID},
	})
	if err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	if _, err := chatService.SendMessage(ctx, alice.User.ID, conversation.ID, chatapp.SendMessageInput{
		Body: "tara basketball later",
	}); err != nil {
		t.Fatalf("send message: %v", err)
	}

	messages, err := chatService.ListMessages(ctx, bob.User.ID, conversation.ID)
	if err != nil {
		t.Fatalf("list messages: %v", err)
	}

	if len(messages) != 1 {
		t.Fatalf("expected 1 message, got %d", len(messages))
	}
}

type userRepositoryStub struct {
	usersByID    map[string]userdomain.User
	usersByEmail map[string]userdomain.User
	profiles     map[string]userdomain.Profile
}

func newUserRepositoryStub() *userRepositoryStub {
	return &userRepositoryStub{
		usersByID:    map[string]userdomain.User{},
		usersByEmail: map[string]userdomain.User{},
		profiles:     map[string]userdomain.Profile{},
	}
}

func (r *userRepositoryStub) CreateUser(_ context.Context, user userdomain.User) error {
	if _, exists := r.usersByEmail[user.Email]; exists {
		return errors.New("email already exists")
	}

	r.usersByID[user.ID] = user
	r.usersByEmail[user.Email] = user
	return nil
}

func (r *userRepositoryStub) FindUserByEmail(_ context.Context, email string) (userdomain.User, error) {
	user, ok := r.usersByEmail[email]
	if !ok {
		return userdomain.User{}, errors.New("user not found")
	}

	return user, nil
}

func (r *userRepositoryStub) GetUser(_ context.Context, userID string) (userdomain.User, error) {
	user, ok := r.usersByID[userID]
	if !ok {
		return userdomain.User{}, errors.New("user not found")
	}

	return user, nil
}

func (r *userRepositoryStub) UpsertProfile(_ context.Context, profile userdomain.Profile) error {
	if profile.LastModified.IsZero() {
		profile.LastModified = time.Now().UTC()
	}

	r.profiles[profile.UserID] = profile
	return nil
}

func (r *userRepositoryStub) GetProfile(_ context.Context, userID string) (userdomain.Profile, error) {
	profile, ok := r.profiles[userID]
	if !ok {
		return userdomain.Profile{}, errors.New("profile not found")
	}

	return profile, nil
}
