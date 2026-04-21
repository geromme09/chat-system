package infra

import (
	"context"
	"errors"
	"strings"

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
		PasswordHash:    user.PasswordHash,
		AccountStatus:   user.AccountStatus,
		AuthProvider:    user.AuthProvider,
		IsVerified:      user.IsVerified,
		ProfileComplete: user.ProfileComplete,
		CreatedAt:       user.CreatedAt,
	}

	if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) || strings.Contains(strings.ToLower(err.Error()), "duplicate key") {
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

func mapUserModel(model userModel) domain.User {
	return domain.User{
		ID:              model.ID,
		Email:           model.Email,
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
