package infra

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/geromme09/chat-system/internal/modules/user/domain"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type PostgresRepository struct {
	db *gorm.DB
}

func NewPostgresRepository(db *gorm.DB) *PostgresRepository {
	return &PostgresRepository{db: db}
}

func (r *PostgresRepository) CreateUser(ctx context.Context, user domain.User) error {
	model := userModel{
		ID:              user.ID,
		Email:           user.Email,
		Username:        user.Username,
		PasswordHash:    user.PasswordHash,
		AccountStatus:   user.AccountStatus,
		AuthProvider:    user.AuthProvider,
		IsVerified:      user.IsVerified,
		ProfileComplete: user.ProfileComplete,
		CreatedAt:       user.CreatedAt,
	}

	if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) || strings.Contains(strings.ToLower(err.Error()), "duplicate key") {
			if strings.Contains(strings.ToLower(err.Error()), "username") {
				return errors.New("username already exists")
			}
			return errors.New("email already exists")
		}
		return err
	}

	return nil
}

func (r *PostgresRepository) FindUserByEmail(ctx context.Context, email string) (domain.User, error) {
	var model userModel
	if err := r.db.WithContext(ctx).Where("email = ?", email).First(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return domain.User{}, errors.New("user not found")
		}
		return domain.User{}, err
	}

	return mapUserModel(model), nil
}

func (r *PostgresRepository) FindUserByUsername(ctx context.Context, username string) (domain.User, error) {
	var model userModel
	if err := r.db.WithContext(ctx).Where("username = ?", username).First(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return domain.User{}, errors.New("user not found")
		}
		return domain.User{}, err
	}

	return mapUserModel(model), nil
}

func (r *PostgresRepository) GetUser(ctx context.Context, userID string) (domain.User, error) {
	var model userModel
	if err := r.db.WithContext(ctx).Where("id = ?", userID).First(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return domain.User{}, errors.New("user not found")
		}
		return domain.User{}, err
	}

	return mapUserModel(model), nil
}

func (r *PostgresRepository) UpsertProfile(ctx context.Context, profile domain.Profile) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		model := profileModel{
			UserID:       profile.UserID,
			DisplayName:  profile.DisplayName,
			Bio:          profile.Bio,
			AvatarURL:    profile.AvatarURL,
			City:         profile.City,
			Country:      profile.Country,
			SkillLevel:   profile.SkillLevel,
			Visible:      profile.Visible,
			LastModified: profile.LastModified,
		}

		if err := tx.Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "user_id"}},
			DoUpdates: clause.AssignmentColumns([]string{
				"display_name",
				"bio",
				"avatar_url",
				"city",
				"country",
				"skill_level",
				"visible",
				"last_modified",
			}),
		}).Create(&model).Error; err != nil {
			return err
		}

		if err := tx.Where("user_id = ?", profile.UserID).Delete(&userSportModel{}).Error; err != nil {
			return err
		}

		sports := make([]userSportModel, 0, len(profile.Sports))
		for _, sport := range profile.Sports {
			sport = strings.TrimSpace(sport)
			if sport == "" {
				continue
			}
			sports = append(sports, userSportModel{
				UserID:    profile.UserID,
				SportName: sport,
			})
		}

		if len(sports) > 0 {
			if err := tx.Create(&sports).Error; err != nil {
				return err
			}
		}

		return nil
	})
}

func (r *PostgresRepository) GetProfile(ctx context.Context, userID string) (domain.Profile, error) {
	var model profileModel
	if err := r.db.WithContext(ctx).Where("user_id = ?", userID).First(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return domain.Profile{}, errors.New("profile not found")
		}
		return domain.Profile{}, err
	}

	var sports []userSportModel
	if err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("sport_name ASC").
		Find(&sports).Error; err != nil {
		return domain.Profile{}, err
	}

	profile := mapProfileModel(model)
	profile.Sports = make([]string, 0, len(sports))
	for _, sport := range sports {
		profile.Sports = append(profile.Sports, sport.SportName)
	}

	return profile, nil
}

func (r *PostgresRepository) SearchUsers(ctx context.Context, query string, limit int, excludeUserID string) ([]domain.SearchResult, error) {
	query = strings.TrimSpace(strings.ToLower(query))
	if query == "" {
		return []domain.SearchResult{}, nil
	}

	if limit <= 0 || limit > 10 {
		limit = 10
	}

	type searchRow struct {
		UserID           string
		Username         string
		DisplayName      string
		AvatarURL        string
		City             string
		FriendshipStatus string
		RequesterUserID  string
	}

	rows := make([]searchRow, 0, limit)
	statement := r.db.WithContext(ctx).
		Table("users").
		Select(`
			users.id AS user_id,
			users.username,
			user_profiles.display_name,
			user_profiles.avatar_url,
			user_profiles.city,
			friendships.status AS friendship_status,
			friendships.requester_user_id
		`).
		Joins("JOIN user_profiles ON user_profiles.user_id = users.id").
		Joins(`
			LEFT JOIN friendships ON
				(
					friendships.requester_user_id = ? AND friendships.addressee_user_id = users.id
				) OR (
					friendships.addressee_user_id = ? AND friendships.requester_user_id = users.id
				)
		`, excludeUserID, excludeUserID).
		Where("users.id <> ?", excludeUserID).
		Where(
			"users.username LIKE ? OR user_profiles.display_name ILIKE ?",
			query+"%",
			"%"+query+"%",
		).
		Order(clause.Expr{
			SQL: `
				CASE
					WHEN users.username = ? THEN 0
					WHEN users.username LIKE ? THEN 1
					ELSE 2
				END,
				users.username ASC
			`,
			Vars: []any{query, query + "%"},
		}).
		Limit(limit)

	if err := statement.Scan(&rows).Error; err != nil {
		return nil, err
	}

	results := make([]domain.SearchResult, 0, len(rows))
	for _, row := range rows {
		results = append(results, domain.SearchResult{
			UserID:           row.UserID,
			Username:         row.Username,
			DisplayName:      row.DisplayName,
			AvatarURL:        row.AvatarURL,
			City:             row.City,
			ConnectionStatus: toConnectionStatus(row.FriendshipStatus, row.RequesterUserID, excludeUserID),
		})
	}

	return results, nil
}

func toConnectionStatus(friendshipStatus, requesterUserID, actorUserID string) string {
	switch friendshipStatus {
	case domain.FriendRequestStatusAccepted:
		return domain.ConnectionStatusFriends
	case domain.FriendRequestStatusPending:
		if requesterUserID == actorUserID {
			return domain.ConnectionStatusRequested
		}
		return domain.ConnectionStatusIncomingRequest
	default:
		return domain.ConnectionStatusAdd
	}
}

func (r *PostgresRepository) GetFriendshipBetween(ctx context.Context, userAID, userBID string) (domain.FriendRequest, error) {
	var model friendshipModel
	if err := r.db.WithContext(ctx).
		Where(
			"(requester_user_id = ? AND addressee_user_id = ?) OR (requester_user_id = ? AND addressee_user_id = ?)",
			userAID,
			userBID,
			userBID,
			userAID,
		).
		Order("created_at DESC").
		First(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return domain.FriendRequest{}, errors.New("friendship not found")
		}
		return domain.FriendRequest{}, err
	}

	return r.getFriendRequestDetails(ctx, model)
}

func (r *PostgresRepository) CreateFriendship(ctx context.Context, friendship domain.FriendRequest) error {
	model := friendshipModel{
		ID:              friendship.ID,
		RequesterUserID: friendship.RequesterID,
		AddresseeUserID: friendship.AddresseeID,
		Status:          friendship.Status,
		SeenAt:          friendship.SeenAt,
		CreatedAt:       friendship.CreatedAt,
		UpdatedAt:       friendship.UpdatedAt,
	}

	return r.db.WithContext(ctx).Create(&model).Error
}

func (r *PostgresRepository) ListIncomingFriendRequests(ctx context.Context, userID string) ([]domain.FriendRequest, error) {
	var models []friendshipModel
	if err := r.db.WithContext(ctx).
		Where(
			"addressee_user_id = ? AND status = ?",
			userID,
			domain.FriendRequestStatusPending,
		).
		Order("created_at DESC").
		Find(&models).Error; err != nil {
		return nil, err
	}

	results := make([]domain.FriendRequest, 0, len(models))
	for _, model := range models {
		detail, err := r.getFriendRequestDetails(ctx, model)
		if err != nil {
			return nil, err
		}
		results = append(results, detail)
	}

	return results, nil
}

func (r *PostgresRepository) UpdateFriendRequestStatus(ctx context.Context, requestID, addresseeUserID, status string, updatedAt time.Time) (domain.FriendRequest, error) {
	var model friendshipModel
	if err := r.db.WithContext(ctx).
		Where("id = ? AND addressee_user_id = ?", requestID, addresseeUserID).
		First(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return domain.FriendRequest{}, errors.New("friend request not found")
		}
		return domain.FriendRequest{}, err
	}

	model.Status = status
	model.UpdatedAt = updatedAt
	model.SeenAt = nil

	if err := r.db.WithContext(ctx).Save(&model).Error; err != nil {
		return domain.FriendRequest{}, err
	}

	return r.getFriendRequestDetails(ctx, model)
}

func (r *PostgresRepository) MarkIncomingFriendRequestsSeen(ctx context.Context, userID string, seenAt time.Time) error {
	return r.db.WithContext(ctx).
		Model(&friendshipModel{}).
		Where(
			"addressee_user_id = ? AND status = ? AND seen_at IS NULL",
			userID,
			domain.FriendRequestStatusPending,
		).
		Updates(map[string]any{
			"seen_at":    seenAt,
			"updated_at": seenAt,
		}).Error
}

func (r *PostgresRepository) ListFriends(ctx context.Context, userID string, offset, limit int) ([]domain.UserCard, error) {
	type friendRow struct {
		UserID      string
		Username    string
		DisplayName string
		AvatarURL   string
		City        string
	}

	rows := make([]friendRow, 0)
	if err := r.db.WithContext(ctx).
		Table("friendships").
		Select(`
			users.id AS user_id,
			users.username,
			user_profiles.display_name,
			user_profiles.avatar_url,
			user_profiles.city
		`).
		Joins(`
			JOIN users ON users.id = CASE
				WHEN friendships.requester_user_id = ? THEN friendships.addressee_user_id
				ELSE friendships.requester_user_id
			END
		`, userID).
		Joins("JOIN user_profiles ON user_profiles.user_id = users.id").
		Where("(friendships.requester_user_id = ? OR friendships.addressee_user_id = ?)", userID, userID).
		Where("friendships.status = ?", domain.FriendRequestStatusAccepted).
		Order("user_profiles.display_name ASC, users.username ASC").
		Offset(offset).
		Limit(limit).
		Scan(&rows).Error; err != nil {
		return nil, err
	}

	results := make([]domain.UserCard, 0, len(rows))
	for _, row := range rows {
		results = append(results, domain.UserCard{
			UserID:      row.UserID,
			Username:    row.Username,
			DisplayName: row.DisplayName,
			AvatarURL:   row.AvatarURL,
			City:        row.City,
		})
	}

	return results, nil
}

func mapUserModel(model userModel) domain.User {
	return domain.User{
		ID:              model.ID,
		Email:           model.Email,
		Username:        model.Username,
		PasswordHash:    model.PasswordHash,
		AccountStatus:   model.AccountStatus,
		AuthProvider:    model.AuthProvider,
		IsVerified:      model.IsVerified,
		ProfileComplete: model.ProfileComplete,
		CreatedAt:       model.CreatedAt,
	}
}

func mapProfileModel(model profileModel) domain.Profile {
	return domain.Profile{
		UserID:       model.UserID,
		DisplayName:  model.DisplayName,
		Bio:          model.Bio,
		AvatarURL:    model.AvatarURL,
		City:         model.City,
		Country:      model.Country,
		SkillLevel:   model.SkillLevel,
		Visible:      model.Visible,
		LastModified: model.LastModified,
	}
}

func (r *PostgresRepository) getFriendRequestDetails(ctx context.Context, model friendshipModel) (domain.FriendRequest, error) {
	requester, err := r.getUserCard(ctx, model.RequesterUserID)
	if err != nil {
		return domain.FriendRequest{}, err
	}

	addressee, err := r.getUserCard(ctx, model.AddresseeUserID)
	if err != nil {
		return domain.FriendRequest{}, err
	}

	return domain.FriendRequest{
		ID:          model.ID,
		RequesterID: model.RequesterUserID,
		AddresseeID: model.AddresseeUserID,
		Status:      model.Status,
		SeenAt:      model.SeenAt,
		CreatedAt:   model.CreatedAt,
		UpdatedAt:   model.UpdatedAt,
		Requester:   requester,
		Addressee:   addressee,
	}, nil
}

func (r *PostgresRepository) getUserCard(ctx context.Context, userID string) (domain.UserCard, error) {
	type cardRow struct {
		UserID      string
		Username    string
		DisplayName string
		AvatarURL   string
		City        string
	}

	var row cardRow
	result := r.db.WithContext(ctx).
		Table("users").
		Select("users.id AS user_id, users.username, user_profiles.display_name, user_profiles.avatar_url, user_profiles.city").
		Joins("JOIN user_profiles ON user_profiles.user_id = users.id").
		Where("users.id = ?", userID).
		Limit(1).
		Scan(&row)
	if result.Error != nil {
		return domain.UserCard{}, result.Error
	}
	if result.RowsAffected == 0 {
		return domain.UserCard{}, errors.New("user not found")
	}

	return domain.UserCard{
		UserID:      row.UserID,
		Username:    row.Username,
		DisplayName: row.DisplayName,
		AvatarURL:   row.AvatarURL,
		City:        row.City,
	}, nil
}
