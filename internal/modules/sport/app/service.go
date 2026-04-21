package app

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/geromme09/chat-system/internal/modules/sport/domain"
)

const sportsCacheTTL = 30 * time.Minute

type Repository = domain.Repository

type Cache interface {
	Get(ctx context.Context, key string) ([]byte, bool, error)
	Set(ctx context.Context, key string, value []byte, ttl time.Duration) error
}

type ListSportsInput struct {
	Query string
	Page  int
	Limit int
}

type ListSportsResult struct {
	Items    []domain.Sport `json:"items"`
	Page     int            `json:"page"`
	Limit    int            `json:"limit"`
	NextPage *int           `json:"next_page,omitempty"`
	Query    string         `json:"query,omitempty"`
}

type Service struct {
	repo  domain.Repository
	cache Cache
}

func NewService(repo domain.Repository, cache Cache) *Service {
	return &Service{
		repo:  repo,
		cache: cache,
	}
}

func (s *Service) ListSports(ctx context.Context, input ListSportsInput) (ListSportsResult, error) {
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

	query := strings.TrimSpace(input.Query)
	cacheKey := fmt.Sprintf("sports:list:q=%s:page=%d:limit=%d", strings.ToLower(query), page, limit)
	if s.cache != nil {
		payload, found, err := s.cache.Get(ctx, cacheKey)
		if err == nil && found {
			var cached ListSportsResult
			if unmarshalErr := json.Unmarshal(payload, &cached); unmarshalErr == nil {
				return cached, nil
			}
		}
	}

	offset := (page - 1) * limit
	rows, err := s.repo.ListSports(ctx, query, offset, limit+1)
	if err != nil {
		return ListSportsResult{}, err
	}

	result := ListSportsResult{
		Page:  page,
		Limit: limit,
		Query: query,
	}
	if len(rows) > limit {
		nextPage := page + 1
		result.NextPage = &nextPage
		rows = rows[:limit]
	}
	result.Items = rows

	if s.cache != nil {
		if payload, marshalErr := json.Marshal(result); marshalErr == nil {
			_ = s.cache.Set(ctx, cacheKey, payload, sportsCacheTTL)
		}
	}

	return result, nil
}
