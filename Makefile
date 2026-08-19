.PHONY: help dev-backend dev-mobile db-up db-migrate test-backend test-flutter test analyze build-backend build-apk build-ipa clean

help:
	@echo "Muxiz Automation & Developer Commands:"
	@echo "  make dev-backend   - Start NestJS backend in development watch mode"
	@echo "  make dev-mobile    - Run Flutter mobile app on connected device"
	@echo "  make db-up         - Start PostgreSQL via Docker Compose"
	@echo "  make db-migrate    - Run Prisma generate & migrations"
	@echo "  make test          - Run full test suite (backend & mobile)"
	@echo "  make analyze       - Run flutter analyze"
	@echo "  make build-backend - Build NestJS backend bundle"
	@echo "  make build-apk     - Build production Android release APK"
	@echo "  make build-ipa     - Build production iOS release IPA"
	@echo "  make clean         - Clean mobile and backend build caches"

dev-backend:
	bash scripts/automate.sh dev-backend

dev-mobile:
	bash scripts/automate.sh dev-mobile

db-up:
	bash scripts/automate.sh db-up

db-migrate:
	bash scripts/automate.sh db-migrate

test-backend:
	bash scripts/automate.sh test-backend

test-flutter:
	bash scripts/automate.sh test-flutter

test:
	bash scripts/automate.sh test

analyze:
	bash scripts/automate.sh analyze

build-backend:
	bash scripts/automate.sh build-backend

build-apk:
	bash scripts/automate.sh build-apk

build-ipa:
	bash scripts/automate.sh build-ipa

clean:
	bash scripts/automate.sh clean
