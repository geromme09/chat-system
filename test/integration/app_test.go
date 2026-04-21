package integration

import (
	"context"
	"testing"

	chatapp "github.com/geromme09/chat-system/internal/modules/chat/app"
	chatinfra "github.com/geromme09/chat-system/internal/modules/chat/infra"
	userapp "github.com/geromme09/chat-system/internal/modules/user/app"
	userinfra "github.com/geromme09/chat-system/internal/modules/user/infra"
	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/messaging"
	"github.com/geromme09/chat-system/internal/platform/storage"
)

func TestSignUpLoginAndChatFlow(t *testing.T) {
	userRepo := userinfra.NewMemoryRepository()
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
