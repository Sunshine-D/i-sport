#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/generate-project.py
python3 scripts/check-project.py
node --test tests/core.test.mjs
(cd ios && swift test)
xcodebuild -project ios/LightMeal.xcodeproj -scheme LightMeal -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
echo 'Mac build and domain checks passed. Camera, real model and HealthKit still require device testing.'
