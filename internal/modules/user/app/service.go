package app

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/geromme09/chat-system/internal/modules/user/domain"
	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/identity"
	"github.com/geromme09/chat-system/internal/platform/storage"
	"github.com/geromme09/chat-system/internal/platform/validate"
)

var ErrInvalidCredentials = errors.New("invalid credentials")

type SignUpInput struct {
	Email          string `json:"email"`
	Password       string `json:"password"`
	DisplayName    string `json:"display_name"`
	Bio            string `json:"bio"`
	AvatarFileName string `json:"avatar_file_name"`
	City           string `json:"city"`
	Country        string `json:"country"`
}

type LoginInput struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type UpdateProfileInput struct {
	DisplayName    string   `json:"display_name"`
	Bio            string   `json:"bio"`
	AvatarFileName string   `json:"avatar_file_name"`
	City           string   `json:"city"`
	Country        string   `json:"country"`
	Sports         []string `json:"sports"`
	SkillLevel     string   `json:"skill_level"`
	Visible        bool     `json:"visible"`
}

type AuthResult struct {
	Token   string         `json:"token"`
	User    domain.User    `json:"user"`
	Profile domain.Profile `json:"profile"`
}

type Service struct {
	repo       domain.Repository
	hasher     auth.PasswordHasher
	tokens     auth.TokenManager
	storage    storage.Service
	timeSource func() time.Time
	idSource   func() string
}

func NewService(repo domain.Repository, hasher auth.PasswordHasher, tokens auth.TokenManager, storage storage.Service) *Service {
	return &Service{
		repo:    repo,
		hasher:  hasher,
		tokens:  tokens,
		storage: storage,
		timeSource: func() time.Time {
			return time.Now().UTC()
		},
		idSource: identity.NewUUID,
	}
}

func (s *Service) SignUp(ctx context.Context, input SignUpInput) (AuthResult, error) {
	if err := validate.Required(input.Email, "email"); err != nil {
		return AuthResult{}, err
	}
	if err := validate.Required(input.Password, "password"); err != nil {
		return AuthResult{}, err
	}
	if err := validate.MinLength(input.Password, 8, "password"); err != nil {
		return AuthResult{}, err
	}
	if err := validate.Required(input.DisplayName, "display_name"); err != nil {
		return AuthResult{}, err
	}

	now := s.timeSource()
	userID := s.idSource()
	passwordHash, err := s.hasher.Hash(input.Password)
	if err != nil {
		return AuthResult{}, err
	}

	user := domain.User{
		ID:              userID,
		Email:           strings.ToLower(strings.TrimSpace(input.Email)),
		PasswordHash:    passwordHash,
		AccountStatus:   "active",
		AuthProvider:    "local",
		IsVerified:      false,
		ProfileComplete: true,
		CreatedAt:       now,
	}
	profile := domain.Profile{
		UserID:       userID,
		DisplayName:  strings.TrimSpace(input.DisplayName),
		Bio:          strings.TrimSpace(input.Bio),
		AvatarURL:    s.storage.AvatarURL(strings.TrimSpace(input.AvatarFileName)),
		City:         strings.TrimSpace(input.City),
		Country:      strings.TrimSpace(input.Country),
		Sports:       []string{},
		SkillLevel:   "",
		Visible:      true,
		LastModified: now,
	}

	if err := s.repo.CreateUser(ctx, user); err != nil {
		return AuthResult{}, err
	}
	if err := s.repo.UpsertProfile(ctx, profile); err != nil {
		return AuthResult{}, err
	}

	return AuthResult{
		Token:   s.tokens.Issue(user.ID),
		User:    user,
		Profile: profile,
	}, nil
}

func (s *Service) Login(ctx context.Context, input LoginInput) (AuthResult, error) {
	user, err := s.repo.FindUserByEmail(ctx, strings.ToLower(strings.TrimSpace(input.Email)))
	if err != nil {
		return AuthResult{}, ErrInvalidCredentials
	}
	if !s.hasher.Compare(input.Password, user.PasswordHash) {
		return AuthResult{}, ErrInvalidCredentials
	}

	profile, err := s.repo.GetProfile(ctx, user.ID)
	if err != nil {
		return AuthResult{}, err
	}

	return AuthResult{
		Token:   s.tokens.Issue(user.ID),
		User:    user,
		Profile: profile,
	}, nil
}

func (s *Service) GetMe(ctx context.Context, userID string) (AuthResult, error) {
	user, err := s.repo.GetUser(ctx, userID)
	if err != nil {
		return AuthResult{}, err
	}

	profile, err := s.repo.GetProfile(ctx, userID)
	if err != nil {
		return AuthResult{}, err
	}

	return AuthResult{
		User:    user,
		Profile: profile,
	}, nil
}

func (s *Service) UpdateProfile(ctx context.Context, userID string, input UpdateProfileInput) (domain.Profile, error) {
	current, err := s.repo.GetProfile(ctx, userID)
	if err != nil {
		return domain.Profile{}, err
	}
	if err := validate.Required(input.DisplayName, "display_name"); err != nil {
		return domain.Profile{}, err
	}

	current.DisplayName = strings.TrimSpace(input.DisplayName)
	current.Bio = strings.TrimSpace(input.Bio)
	if strings.TrimSpace(input.AvatarFileName) != "" {
		current.AvatarURL = s.storage.AvatarURL(strings.TrimSpace(input.AvatarFileName))
	}
	current.City = strings.TrimSpace(input.City)
	current.Country = strings.TrimSpace(input.Country)
	current.Sports = append([]string{}, input.Sports...)
	current.SkillLevel = strings.TrimSpace(input.SkillLevel)
	current.Visible = input.Visible
	current.LastModified = s.timeSource()

	if err := s.repo.UpsertProfile(ctx, current); err != nil {
		return domain.Profile{}, err
	}

	return current, nil
}
