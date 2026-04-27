#!/bin/sh
# ci_post_clone.sh — Xcode Cloud post-clone script
# Resolves Swift Package dependencies after cloning the repo.
# This is needed because Xcode Cloud has automatic dependency resolution
# disabled by default, and new packages added to the project need to be
# resolved before the build can proceed.

set -e

echo "=== Resolving Swift Package dependencies ==="

cd "$CI_PRIMARY_REPOSITORY_PATH"

xcodebuild -resolvePackageDependencies \
  -project "Flow Day-ios.xcodeproj" \
  -scheme "Flow Day-ios"

echo "=== Package dependencies resolved ==="
