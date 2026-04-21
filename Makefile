APP_NAME=chat-system
GOCACHE_DIR=$(CURDIR)/.gocache
API_BASE_URL?=http://localhost:8080
IOS_API_BASE_URL?=http://localhost:8080
ANDROID_API_BASE_URL?=http://10.0.2.2:8080
IOS_DEVICE_NAME?=iPhone 17

.PHONY: help run api infra-up infra-down infra-logs api-logs migrate-logs migrate-up migrate-down migrate-status migrate-create swagger test fmt mobile-get mobile-run mobile-run-ios mobile-run-android
.PHONY: mobile-open-ios mobile-open-android mobile-devices

name?=new_migration

help:
	@printf "\nAvailable targets:\n"
	@printf "  make api          Run the Go API locally\n"
	@printf "  make infra-up     Start Postgres, Redis, RabbitMQ, migrations, and API with Docker\n"
	@printf "  make infra-down   Stop Docker infrastructure\n"
	@printf "  make infra-logs   Show Docker service status and logs\n"
	@printf "  make api-logs     Show API container logs\n"
	@printf "  make migrate-logs Show migration container logs\n"
	@printf "  make migrate-up   Apply pending goose migrations\n"
	@printf "  make migrate-down Roll back the latest goose migration\n"
	@printf "  make migrate-status Show goose migration status\n"
	@printf "  make migrate-create name=add_feature Create a new goose SQL migration\n"
	@printf "  make swagger      Generate Swagger docs with swaggo (requires swag CLI)\n"
	@printf "  make test         Run Go tests with a local build cache\n"
	@printf "  make fmt          Format Go files\n"
	@printf "  make mobile-get   Fetch Flutter dependencies\n"
	@printf "  make mobile-devices      List Flutter-detected devices\n"
	@printf "  make mobile-open-ios     Boot the default iOS simulator and open Simulator\n"
	@printf "  make mobile-open-android Open Android emulator chooser\n"
	@printf "  make mobile-run   Run the Flutter app with API_BASE_URL\n\n"
	@printf "  make mobile-run-ios      Run on the configured iOS Simulator device\n"
	@printf "  make mobile-run-android  Run on Android emulator defaults\n\n"

run: api

api:
	go run ./cmd/api

infra-up:
	docker compose up -d --build

infra-down:
	docker compose down

infra-logs:
	docker compose ps
	docker compose logs --tail=100

api-logs:
	docker compose logs api

migrate-logs:
	docker compose logs migrate

migrate-up:
	docker compose run --rm migrate up

migrate-down:
	docker compose run --rm migrate down

migrate-status:
	docker compose run --rm migrate status

migrate-create:
	docker compose run --rm migrate create $(name) sql

swagger:
	$(shell go env GOPATH)/bin/swag init -g main.go -d cmd/api,internal -o docs/swagger

test:
	env GOCACHE=$(GOCACHE_DIR) go test ./...

fmt:
	gofmt -w $(shell find . -name '*.go' -not -path './mobile/*')

mobile-get:
	cd mobile && flutter pub get

mobile-devices:
	cd mobile && flutter devices

mobile-open-ios:
	xcrun simctl boot "$(IOS_DEVICE_NAME)" || true
	open -a Simulator
	cd mobile && flutter devices

mobile-open-android:
	cd mobile && flutter emulators

mobile-run:
	cd mobile && flutter run --dart-define=API_BASE_URL=$(API_BASE_URL)

mobile-run-ios:
	cd mobile && flutter run -d "$(IOS_DEVICE_NAME)" --dart-define=API_BASE_URL=$(IOS_API_BASE_URL)

mobile-run-android:
	cd mobile && flutter run -d android --dart-define=API_BASE_URL=$(ANDROID_API_BASE_URL)
