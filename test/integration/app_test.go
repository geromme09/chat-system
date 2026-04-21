package integration

import (
	"context"
	"errors"
	"strings"
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
		Username:       "alice_one",
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
		Username:       "bob_two",
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
		Identifier: "alice_one",
		Password:   "password123",
	}); err != nil {
		t.Fatalf("login alice: %v", err)
	}

	friendRequest, err := userService.SendFriendRequest(ctx, alice.User.ID, userapp.SendFriendRequestInput{
		TargetUserID: bob.User.ID,
	})
	if err != nil {
		t.Fatalf("send friend request: %v", err)
	}

	if _, err := userService.RespondToFriendRequest(
		ctx,
		bob.User.ID,
		friendRequest.ID,
		userdomain.FriendRequestStatusAccepted,
	); err != nil {
		t.Fatalf("accept friend request: %v", err)
	}

	friends, err := userService.ListFriends(ctx, alice.User.ID)
	if err != nil {
		t.Fatalf("list friends: %v", err)
	}

	if len(friends) != 1 || friends[0].UserID != bob.User.ID {
		t.Fatalf("expected bob as accepted friend, got %#v", friends)
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
	usersByName  map[string]userdomain.User
	profiles     map[string]userdomain.Profile
	friendships  map[string]userdomain.FriendRequest
}

func newUserRepositoryStub() *userRepositoryStub {
	return &userRepositoryStub{
		usersByID:    map[string]userdomain.User{},
		usersByEmail: map[string]userdomain.User{},
		usersByName:  map[string]userdomain.User{},
		profiles:     map[string]userdomain.Profile{},
		friendships:  map[string]userdomain.FriendRequest{},
	}
}

func (r *userRepositoryStub) CreateUser(_ context.Context, user userdomain.User) error {
	if _, exists := r.usersByEmail[user.Email]; exists {
		return errors.New("email already exists")
	}
	if _, exists := r.usersByName[user.Username]; exists {
		return errors.New("username already exists")
	}

	r.usersByID[user.ID] = user
	r.usersByEmail[user.Email] = user
	r.usersByName[user.Username] = user
	return nil
}

func (r *userRepositoryStub) FindUserByEmail(_ context.Context, email string) (userdomain.User, error) {
	user, ok := r.usersByEmail[email]
	if !ok {
		return userdomain.User{}, errors.New("user not found")
	}

	return user, nil
}

func (r *userRepositoryStub) FindUserByUsername(_ context.Context, username string) (userdomain.User, error) {
	user, ok := r.usersByName[username]
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

func (r *userRepositoryStub) SearchUsers(_ context.Context, query string, limit int, excludeUserID string) ([]userdomain.SearchResult, error) {
	results := make([]userdomain.SearchResult, 0, limit)
	for userID, profile := range r.profiles {
		if userID == excludeUserID {
			continue
		}

		user := r.usersByID[userID]
		if !strings.HasPrefix(user.Username, query) && !strings.Contains(strings.ToLower(profile.DisplayName), strings.ToLower(query)) {
			continue
		}

		results = append(results, userdomain.SearchResult{
			UserID:           user.ID,
			Username:         user.Username,
			DisplayName:      profile.DisplayName,
			AvatarURL:        profile.AvatarURL,
			City:             profile.City,
			ConnectionStatus: userdomain.ConnectionStatusAdd,
		})
		if len(results) == limit {
			break
		}
	}

	return results, nil
}

func (r *userRepositoryStub) GetFriendshipBetween(_ context.Context, userAID, userBID string) (userdomain.FriendRequest, error) {
	for _, friendship := range r.friendships {
		if (friendship.RequesterID == userAID && friendship.AddresseeID == userBID) ||
			(friendship.RequesterID == userBID && friendship.AddresseeID == userAID) {
			return friendship, nil
		}
	}

	return userdomain.FriendRequest{}, errors.New("friendship not found")
}

func (r *userRepositoryStub) CreateFriendship(_ context.Context, friendship userdomain.FriendRequest) error {
	friendship.Requester = r.userCard(friendship.RequesterID)
	friendship.Addressee = r.userCard(friendship.AddresseeID)
	r.friendships[friendship.ID] = friendship
	return nil
}

func (r *userRepositoryStub) ListIncomingFriendRequests(_ context.Context, userID string) ([]userdomain.FriendRequest, error) {
	requests := make([]userdomain.FriendRequest, 0)
	for _, friendship := range r.friendships {
		if friendship.AddresseeID == userID &&
			friendship.Status == userdomain.FriendRequestStatusPending {
			requests = append(requests, friendship)
		}
	}
	return requests, nil
}

func (r *userRepositoryStub) UpdateFriendRequestStatus(_ context.Context, requestID, addresseeUserID, status string, updatedAt time.Time) (userdomain.FriendRequest, error) {
	friendship, ok := r.friendships[requestID]
	if !ok || friendship.AddresseeID != addresseeUserID {
		return userdomain.FriendRequest{}, errors.New("friend request not found")
	}

	friendship.Status = status
	friendship.UpdatedAt = updatedAt
	friendship.SeenAt = &updatedAt
	friendship.Requester = r.userCard(friendship.RequesterID)
	friendship.Addressee = r.userCard(friendship.AddresseeID)
	r.friendships[requestID] = friendship
	return friendship, nil
}

func (r *userRepositoryStub) MarkIncomingFriendRequestsSeen(_ context.Context, userID string, seenAt time.Time) error {
	for id, friendship := range r.friendships {
		if friendship.AddresseeID == userID &&
			friendship.Status == userdomain.FriendRequestStatusPending &&
			friendship.SeenAt == nil {
			friendship.SeenAt = &seenAt
			friendship.UpdatedAt = seenAt
			r.friendships[id] = friendship
		}
	}
	return nil
}

func (r *userRepositoryStub) ListFriends(_ context.Context, userID string) ([]userdomain.UserCard, error) {
	friends := make([]userdomain.UserCard, 0)
	for _, friendship := range r.friendships {
		if friendship.Status != userdomain.FriendRequestStatusAccepted {
			continue
		}
		if friendship.RequesterID == userID {
			friends = append(friends, r.userCard(friendship.AddresseeID))
		} else if friendship.AddresseeID == userID {
			friends = append(friends, r.userCard(friendship.RequesterID))
		}
	}
	return friends, nil
}

func (r *userRepositoryStub) userCard(userID string) userdomain.UserCard {
	user := r.usersByID[userID]
	profile := r.profiles[userID]
	return userdomain.UserCard{
		UserID:      user.ID,
		Username:    user.Username,
		DisplayName: profile.DisplayName,
		AvatarURL:   profile.AvatarURL,
		City:        profile.City,
	}
}
