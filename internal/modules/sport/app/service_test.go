package app

import (
	"context"
	"testing"
	"time"

	"github.com/geromme09/chat-system/internal/modules/sport/domain"
)

func TestListSportsUsesDefaultLimitAndPagination(t *testing.T) {
	t.Parallel()

	service := NewService(
		stubRepository{sports: makeSports(18)},
		&stubCache{},
	)

	result, err := service.ListSports(context.Background(), ListSportsInput{})
	if err != nil {
		t.Fatalf("ListSports returned error: %v", err)
	}

	if len(result.Items) != 15 {
		t.Fatalf("expected 15 items, got %d", len(result.Items))
	}
	if result.NextPage == nil || *result.NextPage != 2 {
		t.Fatalf("expected next page to be 2, got %#v", result.NextPage)
	}
}

func TestListSportsFiltersAndCachesResults(t *testing.T) {
	t.Parallel()

	cache := &stubCache{}
	repo := stubRepository{
		sports: []domain.Sport{
			{ID: "11111111-1111-1111-1111-111111111111", Name: "Basketball", Slug: "basketball", IsActive: true, SortOrder: 10},
			{ID: "22222222-2222-2222-2222-222222222222", Name: "Badminton", Slug: "badminton", IsActive: true, SortOrder: 20},
		},
	}
	service := NewService(repo, cache)

	first, err := service.ListSports(context.Background(), ListSportsInput{Query: "ball", Limit: 15, Page: 1})
	if err != nil {
		t.Fatalf("first ListSports returned error: %v", err)
	}
	if len(first.Items) != 1 || first.Items[0].Name != "Basketball" {
		t.Fatalf("unexpected first result: %#v", first.Items)
	}

	cached, err := service.ListSports(context.Background(), ListSportsInput{Query: "ball", Limit: 15, Page: 1})
	if err != nil {
		t.Fatalf("cached ListSports returned error: %v", err)
	}
	if len(cached.Items) != 1 || cached.Items[0].Name != "Basketball" {
		t.Fatalf("unexpected cached result: %#v", cached.Items)
	}

	if cache.setCalls != 1 {
		t.Fatalf("expected one cache write, got %d", cache.setCalls)
	}
}

type stubRepository struct {
	sports []domain.Sport
}

func (r stubRepository) ListSports(_ context.Context, query string, offset, limit int) ([]domain.Sport, error) {
	filtered := make([]domain.Sport, 0, len(r.sports))
	for _, sport := range r.sports {
		if query == "" || sport.Name == "Basketball" {
			filtered = append(filtered, sport)
		}
	}

	if offset >= len(filtered) {
		return []domain.Sport{}, nil
	}

	end := offset + limit
	if end > len(filtered) {
		end = len(filtered)
	}

	return append([]domain.Sport(nil), filtered[offset:end]...), nil
}

type stubCache struct {
	store    map[string][]byte
	setCalls int
}

func (c *stubCache) Get(_ context.Context, key string) ([]byte, bool, error) {
	if c.store == nil {
		return nil, false, nil
	}

	value, ok := c.store[key]
	return value, ok, nil
}

func (c *stubCache) Set(_ context.Context, key string, value []byte, _ time.Duration) error {
	if c.store == nil {
		c.store = map[string][]byte{}
	}
	c.store[key] = append([]byte(nil), value...)
	c.setCalls++
	return nil
}

func makeSports(total int) []domain.Sport {
	sports := make([]domain.Sport, 0, total)
	for i := 0; i < total; i++ {
		sports = append(sports, domain.Sport{
			ID:        "11111111-1111-1111-1111-111111111111",
			Name:      "Sport",
			Slug:      "sport",
			IsActive:  true,
			SortOrder: i,
		})
	}
	return sports
}
