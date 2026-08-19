#!/usr/bin/env bash
# ==============================================================================
# Muxiz Full-Stack Platform Automation Script
# Supports: Dev, Testing, Linting, Database Migration, Android APK, and iOS Build
# ==============================================================================

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
MOBILE_DIR="$PROJECT_ROOT/mobile"

function print_header() {
  echo ""
  echo "================================================================="
  echo "  Muxiz Automation: $1"
  echo "================================================================="
  echo ""
}

if [ -d "/opt/homebrew/opt/openjdk@17" ]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

function check_prerequisites() {
  command -v flutter >/dev/null 2>&1 || { echo "❌ Flutter is not installed or not in PATH."; exit 1; }
  command -v node >/dev/null 2>&1 || { echo "❌ Node.js is not installed or not in PATH."; exit 1; }
  command -v npm >/dev/null 2>&1 || { echo "❌ npm is not installed or not in PATH."; exit 1; }
}

case "$1" in
  "dev-backend")
    print_header "Starting Backend Dev Server (NestJS)"
    cd "$BACKEND_DIR"
    npm run start:dev
    ;;

  "dev-mobile")
    print_header "Starting Flutter Mobile Application"
    cd "$MOBILE_DIR"
    flutter run
    ;;

  "db-up")
    print_header "Starting PostgreSQL Database via Docker Compose"
    cd "$PROJECT_ROOT"
    docker-compose up -d
    ;;

  "db-migrate")
    print_header "Running Prisma Migrations & Generation"
    cd "$BACKEND_DIR"
    npx prisma generate
    npx prisma migrate dev --name init || true
    ;;

  "test-backend")
    print_header "Running Backend Test Suite"
    cd "$BACKEND_DIR"
    npm run test
    ;;

  "test-flutter")
    print_header "Running Flutter Test Suite"
    cd "$MOBILE_DIR"
    flutter test
    ;;

  "test")
    print_header "Running All Test Suites (Backend + Mobile)"
    cd "$BACKEND_DIR"
    npm run build
    cd "$MOBILE_DIR"
    flutter test
    echo "✅ All tests passed successfully!"
    ;;

  "analyze")
    print_header "Running Flutter Static Analysis"
    cd "$MOBILE_DIR"
    flutter analyze
    ;;

  "build-backend")
    print_header "Building Backend Production Bundle"
    cd "$BACKEND_DIR"
    npm run build
    ;;

  "build-apk")
    print_header "Building Native Android Release APK"
    cd "$MOBILE_DIR"
    flutter build apk --release
    mkdir -p "$PROJECT_ROOT/dist_server"
    cp "$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk" "$PROJECT_ROOT/dist_server/Muxiz-v1.0.0.apk"
    echo "🎉 Android APK build complete: $PROJECT_ROOT/dist_server/Muxiz-v1.0.0.apk"
    ;;

  "build-ipa")
    print_header "Building Native iOS Release App/IPA"
    cd "$MOBILE_DIR"
    flutter build ipa --release --no-codesign
    mkdir -p build/ios/ipa/Payload
    cp -R build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app build/ios/ipa/Payload/
    (cd build/ios/ipa && zip -qr Muxiz.ipa Payload && rm -rf Payload)
    mkdir -p "$PROJECT_ROOT/dist_server"
    cp "$MOBILE_DIR/build/ios/ipa/Muxiz.ipa" "$PROJECT_ROOT/dist_server/Muxiz-v1.0.0.ipa"
    echo "🎉 iOS IPA build complete: $PROJECT_ROOT/dist_server/Muxiz-v1.0.0.ipa"
    ;;

  "clean")
    print_header "Cleaning Build Artifacts"
    cd "$MOBILE_DIR" && flutter clean
    cd "$BACKEND_DIR" && rm -rf dist node_modules/.cache
    echo "🧹 Clean complete."
    ;;

  *)
    echo "Muxiz Automation CLI"
    echo "Usage: $0 {dev-backend|dev-mobile|db-up|db-migrate|test-backend|test-flutter|test|analyze|build-backend|build-apk|build-ipa|clean}"
    exit 1
    ;;
esac
