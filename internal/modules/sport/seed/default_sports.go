package seed

import "github.com/geromme09/chat-system/internal/modules/sport/domain"

func DefaultSports() []domain.Sport {
	return []domain.Sport{
		{ID: "4d2b0b0d-a706-4de0-b2fa-2fe7c59ec6f6", Name: "Basketball", Slug: "basketball", IsActive: true, SortOrder: 10},
		{ID: "2c8fba34-33ea-4ba5-bb65-8c9d1f9af877", Name: "Badminton", Slug: "badminton", IsActive: true, SortOrder: 20},
		{ID: "b1c7f2aa-aef9-4dd4-b811-8a823eb2ef7e", Name: "Volleyball", Slug: "volleyball", IsActive: true, SortOrder: 30},
		{ID: "94c1c028-2dde-4323-9d86-cf7091748548", Name: "Table Tennis", Slug: "table-tennis", IsActive: true, SortOrder: 40},
		{ID: "d7bb8fa9-32f5-4b2c-ab20-24a5352a1798", Name: "Tennis", Slug: "tennis", IsActive: true, SortOrder: 50},
		{ID: "670bde52-a83c-4ed8-839c-b080fcd69dd1", Name: "Futsal", Slug: "futsal", IsActive: true, SortOrder: 60},
		{ID: "20efaa0b-bf56-4195-8f2c-f3945cf98133", Name: "Football", Slug: "football", IsActive: true, SortOrder: 70},
		{ID: "cf68df2c-faa6-4e07-a8d3-fbdd3450198f", Name: "Boxing", Slug: "boxing", IsActive: true, SortOrder: 80},
		{ID: "20d71d7d-38ae-4b55-8f8e-aedfb931f4dd", Name: "MMA", Slug: "mma", IsActive: true, SortOrder: 90},
		{ID: "c1d5bdc8-7690-4f0e-84e8-c52505b19434", Name: "Billiards", Slug: "billiards", IsActive: true, SortOrder: 100},
		{ID: "7d937470-89d9-4d16-84f5-9cd85e11d6ca", Name: "Bowling", Slug: "bowling", IsActive: true, SortOrder: 110},
		{ID: "80c67aef-649f-48bd-8b54-b417b559b4e6", Name: "Swimming", Slug: "swimming", IsActive: true, SortOrder: 120},
		{ID: "006457b7-b6d0-44e3-bc1c-c20da49a26f1", Name: "Running", Slug: "running", IsActive: true, SortOrder: 130},
		{ID: "bf8e1e5b-d791-449f-b6c8-5127af99fd9c", Name: "Cycling", Slug: "cycling", IsActive: true, SortOrder: 140},
		{ID: "30c0ef26-7e99-4eae-b7d0-0845904c4898", Name: "Pickleball", Slug: "pickleball", IsActive: true, SortOrder: 150},
		{ID: "fd13e7e3-652a-44a0-b822-4f0f5cb6fb4a", Name: "Golf", Slug: "golf", IsActive: true, SortOrder: 160},
		{ID: "6a31a694-113d-4ea2-87d8-2f0f8908fccd", Name: "Baseball", Slug: "baseball", IsActive: true, SortOrder: 170},
		{ID: "29fa5e2b-e86e-474e-bb6f-42cc202306ea", Name: "Softball", Slug: "softball", IsActive: true, SortOrder: 180},
		{ID: "3977ae58-f3e6-4149-964f-86770b65d9ec", Name: "Skateboarding", Slug: "skateboarding", IsActive: true, SortOrder: 190},
		{ID: "ae8f041f-9004-42cf-a5db-a7e909975744", Name: "Climbing", Slug: "climbing", IsActive: true, SortOrder: 200},
	}
}
