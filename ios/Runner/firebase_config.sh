#!/bin/sh
# Optional Firebase setup, run as an Xcode build phase.
#
# GoogleService-Info.plist is NOT committed to git (it is listed in
# .gitignore). If you have downloaded it into ios/Runner/, this bundles it into
# the app and adds the URL scheme Firebase phone login needs. If it is absent
# the app still builds and simply runs without Firebase (demo login).

PLIST="${SRCROOT}/Runner/GoogleService-Info.plist"
APP="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
INFO="${APP}/Info.plist"

if [ ! -f "$PLIST" ]; then
  echo "note: no GoogleService-Info.plist found: building without Firebase."
  exit 0
fi

cp "$PLIST" "${APP}/GoogleService-Info.plist"

# URL scheme = the encoded app id, e.g. 1:123:ios:abc -> app-1-123-ios-abc
APP_ID=$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$PLIST" 2>/dev/null)
if [ -n "$APP_ID" ]; then
  SCHEME="app-$(echo "$APP_ID" | tr ':' '-')"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes" "$INFO" 2>/dev/null
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$INFO"
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$INFO"
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$INFO"
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$INFO"
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $SCHEME" "$INFO"
fi
echo "note: bundled Firebase configuration."
