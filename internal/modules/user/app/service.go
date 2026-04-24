package app

import (
	"context"
	"errors"
	"regexp"
	"strings"
	"time"

	"github.com/geromme09/chat-system/internal/modules/user/domain"
	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/identity"
	"github.com/geromme09/chat-system/internal/platform/messaging"
	"github.com/geromme09/chat-system/internal/platform/storage"
	"github.com/geromme09/chat-system/internal/platform/validate"
)

var ErrInvalidCredentials = errors.New("invalid credentials")
var ErrDuplicateFriendRequest = errors.New("friend request already exists")
var usernamePattern = regexp.MustCompile(`^[a-z0-9_]{3,20}$`)

type SignUpInput struct {
	Email          string `json:"email" validate:"required"`
	Username       string `json:"username" validate:"required"`
	Password       string `json:"password" validate:"required,min=8"`
	DisplayName    string `json:"display_name" validate:"required"`
	Bio            string `json:"bio"`
	AvatarFileName string `json:"avatar_file_name"`
	City           string `json:"city"`
	Country        string `json:"country"`
}

type LoginInput struct {
	Identifier string `json:"identifier" validate:"required"`
	Password   string `json:"password" validate:"required,min=8"`
}

type UpdateProfileInput struct {
	DisplayName    string `json:"display_name" validate:"required"`
	Bio            string `json:"bio"`
	AvatarFileName string `json:"avatar_file_name"`
	City           string `json:"city"`
	Country        string `json:"country"`
	Gender         string `json:"gender"`
	HobbiesText    string `json:"hobbies_text"`
	Visible        bool   `json:"visible"`
}

type AuthResult struct {
	Token   string         `json:"token"`
	User    domain.User    `json:"user"`
	Profile domain.Profile `json:"profile"`
}

type SearchUsersInput struct {
	Query       string
	Limit       int
	ExcludeUser string
}

type SendFriendRequestInput struct {
	TargetUserID string `json:"target_user_id"`
}

type ListFriendsInput struct {
	Page  int
	Limit int
}

type FriendRequestNotifier interface {
	NotifyFriendRequestCreated(ctx context.Context, friendRequest domain.FriendRequest) error
	NotifyFriendRequestResponded(ctx context.Context, friendRequest domain.FriendRequest) error
}

type FriendConnectionMessenger interface {
	EnsureFriendConnection(ctx context.Context, requesterUserID, addresseeUserID string) error
}

type Service struct {
	repo       domain.Repository
	hasher     auth.PasswordHasher
	tokens     auth.TokenManager
	storage    storage.Service
	publisher  messaging.Publisher
	notifier   FriendRequestNotifier
	messenger  FriendConnectionMessenger
	timeSource func() time.Time
	idSource   func() string
}

func NewService(repo domain.Repository, hasher auth.PasswordHasher, tokens auth.TokenManager, storage storage.Service, publisher messaging.Publisher, notifier FriendRequestNotifier, messenger FriendConnectionMessenger) *Service {
	return &Service{
		repo:      repo,
		hasher:    hasher,
		tokens:    tokens,
		storage:   storage,
		publisher: publisher,
		notifier:  notifier,
		messenger: messenger,
		timeSource: func() time.Time {
			return time.Now().UTC()
		},
		idSource: identity.NewUUID,
	}
}

func (s *Service) SignUp(ctx context.Context, input SignUpInput) (AuthResult, error) {
	if err := validate.Struct(input); err != nil {
		return AuthResult{}, err
	}

	username := normalizeUsername(input.Username)
	if !usernamePattern.MatchString(username) {
		return AuthResult{}, errors.New("username must be 3-20 characters using lowercase letters, numbers, or underscores")
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
		Username:        username,
		PasswordHash:    passwordHash,
		AccountStatus:   "active",
		AuthProvider:    "local",
		IsVerified:      false,
		ProfileComplete: false,
		CreatedAt:       now,
	}
	profile := domain.Profile{
		UserID:       userID,
		DisplayName:  strings.TrimSpace(input.DisplayName),
		Bio:          strings.TrimSpace(input.Bio),
		AvatarURL:    s.storage.AvatarURL(strings.TrimSpace(input.AvatarFileName)),
		City:         strings.TrimSpace(input.City),
		Country:      strings.TrimSpace(input.Country),
		Gender:       "",
		HobbiesText:  "",
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
	if err := validate.Struct(input); err != nil {
		return AuthResult{}, ErrInvalidCredentials
	}

	identifier := strings.TrimSpace(input.Identifier)

	var (
		user domain.User
		err  error
	)

	if strings.Contains(identifier, "@") {
		user, err = s.repo.FindUserByEmail(ctx, strings.ToLower(identifier))
	} else {
		user, err = s.repo.FindUserByUsername(ctx, normalizeUsername(identifier))
	}
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

func (s *Service) SearchUsers(ctx context.Context, input SearchUsersInput) ([]domain.SearchResult, error) {
	query := strings.TrimSpace(input.Query)
	if len(query) < 2 {
		return []domain.SearchResult{}, nil
	}

	limit := input.Limit
	if limit <= 0 || limit > 10 {
		limit = 10
	}

	return s.repo.SearchUsers(ctx, query, limit, input.ExcludeUser)
}

func (s *Service) SendFriendRequest(ctx context.Context, actorUserID string, input SendFriendRequestInput) (domain.FriendRequest, error) {
	targetUserID := strings.TrimSpace(input.TargetUserID)
	if targetUserID == "" {
		return domain.FriendRequest{}, errors.New("target_user_id is required")
	}
	if targetUserID == actorUserID {
		return domain.FriendRequest{}, errors.New("cannot add yourself")
	}
	if _, err := s.repo.GetUser(ctx, targetUserID); err != nil {
		return domain.FriendRequest{}, err
	}

	existing, err := s.repo.GetFriendshipBetween(ctx, actorUserID, targetUserID)
	if err == nil {
		switch existing.Status {
		case domain.FriendRequestStatusPending:
			return domain.FriendRequest{}, ErrDuplicateFriendRequest
		case domain.FriendRequestStatusAccepted:
			return domain.FriendRequest{}, errors.New("already friends")
		case domain.FriendRequestStatusDeclined:
			return domain.FriendRequest{}, ErrDuplicateFriendRequest
		}
	}

	now := s.timeSource()
	friendRequest := domain.FriendRequest{
		ID:          s.idSource(),
		RequesterID: actorUserID,
		AddresseeID: targetUserID,
		Status:      domain.FriendRequestStatusPending,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	if err := s.repo.CreateFriendship(ctx, friendRequest); err != nil {
		return domain.FriendRequest{}, err
	}

	created, err := s.repo.GetFriendshipBetween(ctx, actorUserID, targetUserID)
	if err != nil {
		return domain.FriendRequest{}, err
	}

	_ = s.publisher.Publish(ctx, messaging.Event{
		Name:        domain.EventFriendRequestCreated,
		Version:     1,
		Aggregate:   "friend_request",
		AggregateID: created.ID,
		Payload: map[string]any{
			domain.EventPayloadFriendRequest: created,
		},
	})
	if s.notifier != nil {
		_ = s.notifier.NotifyFriendRequestCreated(ctx, created)
	}

	return created, nil
}

func (s *Service) ListIncomingFriendRequests(ctx context.Context, actorUserID string) ([]domain.FriendRequest, error) {
	return s.repo.ListIncomingFriendRequests(ctx, actorUserID)
}

func (s *Service) RespondToFriendRequest(ctx context.Context, actorUserID, requestID, status string) (domain.FriendRequest, error) {
	status = strings.TrimSpace(status)
	if status != domain.FriendRequestStatusAccepted &&
		status != domain.FriendRequestStatusDeclined {
		return domain.FriendRequest{}, errors.New("invalid friend request status")
	}

	friendRequest, err := s.repo.UpdateFriendRequestStatus(ctx, requestID, actorUserID, status, s.timeSource())
	if err != nil {
		return domain.FriendRequest{}, err
	}

	_ = s.publisher.Publish(ctx, messaging.Event{
		Name:        domain.EventFriendRequestResponded,
		Version:     1,
		Aggregate:   "friend_request",
		AggregateID: friendRequest.ID,
		Payload: map[string]any{
			domain.EventPayloadFriendRequest: friendRequest,
		},
	})
	if s.notifier != nil {
		_ = s.notifier.NotifyFriendRequestResponded(ctx, friendRequest)
	}
	if status == domain.FriendRequestStatusAccepted && s.messenger != nil {
		_ = s.messenger.EnsureFriendConnection(
			ctx,
			friendRequest.RequesterID,
			friendRequest.AddresseeID,
		)
	}

	return friendRequest, nil
}

func (s *Service) ListFriends(ctx context.Context, actorUserID string, input ListFriendsInput) (domain.FriendsPage, error) {
	page := input.Page
	if page < 1 {
		page = 1
	}

	limit := input.Limit
	switch {
	case limit <= 0:
		limit = 15
	case limit > 50:
		limit = 50
	}

	offset := (page - 1) * limit
	rows, err := s.repo.ListFriends(ctx, actorUserID, offset, limit+1)
	if err != nil {
		return domain.FriendsPage{}, err
	}

	result := domain.FriendsPage{
		Items: rows,
		Page:  page,
		Limit: limit,
	}
	if len(rows) > limit {
		nextPage := page + 1
		result.NextPage = &nextPage
		result.Items = rows[:limit]
	}

	return result, nil
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

func (s *Service) GetPublicProfile(ctx context.Context, actorUserID, targetUserID string) (domain.PublicProfile, error) {
	targetUserID = strings.TrimSpace(targetUserID)
	if targetUserID == "" {
		return domain.PublicProfile{}, errors.New("target user id is required")
	}

	return s.repo.GetPublicProfile(ctx, actorUserID, targetUserID)
}

func (s *Service) UpdateProfile(ctx context.Context, userID string, input UpdateProfileInput) (domain.Profile, error) {
	current, err := s.repo.GetProfile(ctx, userID)
	if err != nil {
		return domain.Profile{}, err
	}
	if err := validate.Struct(input); err != nil {
		return domain.Profile{}, err
	}

	current.DisplayName = strings.TrimSpace(input.DisplayName)
	current.Bio = strings.TrimSpace(input.Bio)
	if strings.TrimSpace(input.AvatarFileName) != "" {
		current.AvatarURL = s.storage.AvatarURL(strings.TrimSpace(input.AvatarFileName))
	}
	current.City = strings.TrimSpace(input.City)
	current.Country = strings.TrimSpace(input.Country)
	current.Gender = strings.TrimSpace(input.Gender)
	current.HobbiesText = strings.TrimSpace(input.HobbiesText)
	current.Visible = input.Visible
	current.LastModified = s.timeSource()

	if err := s.repo.UpsertProfile(ctx, current); err != nil {
		return domain.Profile{}, err
	}

	return current, nil
}

func normalizeUsername(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}
