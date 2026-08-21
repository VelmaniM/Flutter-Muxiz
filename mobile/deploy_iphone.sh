#!/bin/bash
set -e

PROFILE_PATH="/Users/velmanikandan/Library/Developer/Xcode/UserData/Provisioning Profiles/e03fdc54-c6e3-4700-b5e5-0e51a4124883.mobileprovision"
APP_PATH="build/ios/iphoneos/Runner.app"
DEVICE_ID="00008150-001C44D61499401C"
CERT="Apple Development: velmani215@gmail.com (55874NWM2F)"

echo "📦 Embedding provisioning profile into Runner.app..."
cp "$PROFILE_PATH" "$APP_PATH/embedded.mobileprovision"

echo "📋 Extracting Entitlements..."
security cms -D -i "$APP_PATH/embedded.mobileprovision" > /tmp/provision.plist
/usr/libexec/PlistBuddy -x -c "Print :Entitlements" /tmp/provision.plist > /tmp/entitlements.plist

echo "🔑 Signing all embedded frameworks..."
if [ -d "$APP_PATH/Frameworks" ]; then
  for framework in "$APP_PATH"/Frameworks/*; do
    if [ -d "$framework" ]; then
      codesign --force --verify --verbose --sign "$CERT" "$framework"
    fi
  done
fi

echo "🔑 Signing Runner.app with entitlements..."
codesign --force --verify --verbose --sign "$CERT" --entitlements /tmp/entitlements.plist "$APP_PATH"

echo "📲 Installing on iPhone ($DEVICE_ID)..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "🚀 Launching Muxiz App on iPhone..."
xcrun devicectl device process launch --device "$DEVICE_ID" com.muxiz.app.mobile

echo "✨ SUCCESS! Muxiz is installed and running on your iPhone!"
