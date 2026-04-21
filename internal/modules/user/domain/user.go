package domain

import (
	"context"
	"time"
)

type User struct {
	ID              string    `json:"id"`
	Email           string    `json:"email"`
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
	Sports       []string  `json:"sports"`
	SkillLevel   string    `json:"skill_level"`
	Visible      bool      `json:"visible"`
	LastModified time.Time `json:"last_modified"`
}

type Repository interface {
	CreateUser(ctx context.Context, user User) error
	FindUserByEmail(ctx context.Context, email string) (User, error)
	GetUser(ctx context.Context, userID string) (User, error)
	UpsertProfile(ctx context.Context, profile Profile) error
	GetProfile(ctx context.Context, userID string) (Profile, error)
}
