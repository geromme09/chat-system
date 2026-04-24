package domain

import (
	"context"
	"time"
)

const (
	FriendRequestStatusPending  = "pending"
	FriendRequestStatusAccepted = "accepted"
	FriendRequestStatusDeclined = "declined"

	EventFriendRequestCreated   = "user.friend_request.created"
	EventFriendRequestResponded = "user.friend_request.responded"
	EventPayloadFriendRequest   = "friend_request"

	ConnectionStatusAdd             = "add"
	ConnectionStatusRequested       = "requested"
	ConnectionStatusIncomingRequest = "incoming_request"
	ConnectionStatusFriends         = "friends"
)

type User struct {
	ID              string    `json:"id"`
	Email           string    `json:"email"`
	Username        string    `json:"username"`
	PasswordHash    string    `json:"-"`
	AccountStatus   string    `json:"account_status"`
	AuthProvider    string    `json:"auth_provider"`
	IsVerified      bool      `json:"is_verified"`
	ProfileComplete bool      `json:"profile_complete"`
	CreatedAt       time.Time `json:"created_at"`
}

type Profile struct {
	UserID       string    `json:"user_id"`
	DisplayName  string    `json:"display_name"`
	Bio          string    `json:"bio"`
	AvatarURL    string    `json:"avatar_url"`
	City         string    `json:"city"`
	Country      string    `json:"country"`
	Gender       string    `json:"gender"`
	HobbiesText  string    `json:"hobbies_text"`
	Visible      bool      `json:"visible"`
	LastModified time.Time `json:"last_modified"`
}

type SearchResult struct {
	UserID           string `json:"user_id"`
	Username         string `json:"username"`
	DisplayName      string `json:"display_name"`
	AvatarURL        string `json:"avatar_url"`
	City             string `json:"city"`
	ConnectionStatus string `json:"connection_status"`
}

type PublicProfile struct {
	UserID           string `json:"user_id"`
	Username         string `json:"username"`
	DisplayName      string `json:"display_name"`
	AvatarURL        string `json:"avatar_url"`
	City             string `json:"city"`
	Country          string `json:"country"`
	Bio              string `json:"bio"`
	Gender           string `json:"gender"`
	HobbiesText      string `json:"hobbies_text"`
	Visible          bool   `json:"visible"`
	ConnectionStatus string `json:"connection_status"`
}

type FriendRequest struct {
	ID          string     `json:"id"`
	RequesterID string     `json:"requester_user_id"`
	AddresseeID string     `json:"addressee_user_id"`
	Status      string     `json:"status"`
	SeenAt      *time.Time `json:"seen_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	Requester   UserCard   `json:"requester"`
	Addressee   UserCard   `json:"addressee"`
}

type UserCard struct {
	UserID      string `json:"user_id"`
	Username    string `json:"username"`
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url"`
	City        string `json:"city"`
}

type FriendsPage struct {
	Items    []UserCard `json:"items"`
	Page     int        `json:"page"`
	Limit    int        `json:"limit"`
	NextPage *int       `json:"next_page,omitempty"`
}

type Repository interface {
	CreateUser(ctx context.Context, user User) error
	FindUserByEmail(ctx context.Context, email string) (User, error)
	FindUserByUsername(ctx context.Context, username string) (User, error)
	GetUser(ctx context.Context, userID string) (User, error)
	UpsertProfile(ctx context.Context, profile Profile) error
	GetProfile(ctx context.Context, userID string) (Profile, error)
	GetPublicProfile(ctx context.Context, actorUserID, targetUserID string) (PublicProfile, error)
	SearchUsers(ctx context.Context, query string, limit int, excludeUserID string) ([]SearchResult, error)
	GetFriendshipBetween(ctx context.Context, userAID, userBID string) (FriendRequest, error)
	CreateFriendship(ctx context.Context, friendship FriendRequest) error
	ListIncomingFriendRequests(ctx context.Context, userID string) ([]FriendRequest, error)
	UpdateFriendRequestStatus(ctx context.Context, requestID, addresseeUserID, status string, updatedAt time.Time) (FriendRequest, error)
	MarkIncomingFriendRequestsSeen(ctx context.Context, userID string, seenAt time.Time) error
	ListFriends(ctx context.Context, userID string, offset, limit int) ([]UserCard, error)
}
