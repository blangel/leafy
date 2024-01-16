#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# by default both ios and android will be compiled, use the first argument to the script to specify a single platform
platform=${1:-both}

# compile the share_signer files
pushd "$SCRIPT_DIR/../core" > /dev/null || exit

# project files don't depend directly on gomobile bind and so 'go mod tidy' may remove the dep, explicitly add here
go get golang.org/x/mobile/bind

# create output directory
mkdir -p target/ > /dev/null

# ios compilation
if [ "$platform" == "both" ] || [ "$platform" == "ios" ]; then
  echo "using gomobile to compile ios"
  gomobile bind -v -target=iossimulator,ios -iosversion 13 -o target/leafy.xcframework ./
  cat > target/leafy.xcframework/leafy.podspec <<'EOF'
Pod::Spec.new do |s|
  s.name             = 'leafy'
  s.version          = '1.0.0'
  s.summary          = 'core code transcompiled from gomobile for leafy'
  s.vendored_frameworks = 'leafy.xcframework'
  s.platform         = :ios, '13.0'
  s.homepage         = 'https://leafybitcoin.com'
  s.license          = { :type => 'Apache 2.0', :file => '../../../LICENSE' }
  s.author           = { 'Brian Langel' => 'blangel@leafybitcoin.com' }
  s.source           = { :http => 'https://github.com/blangel/leafy' }
end
EOF
  cp -R target/leafy.xcframework ../frontend/ios/
fi

# android compilation
if [ "$platform" == "both" ] || [ "$platform" == "android" ]; then
  echo "using gomobile to compile android"
  mkdir -p ../frontend/android/app/libs/
  gomobile bind -v -target=android/arm64,android/amd64 -androidapi 19 -o target/leafy.aar core
  cp target/leafy.aar ../frontend/android/app/libs/
  cp target/leafy-sources.jar ../frontend/android/app/libs/
fi

popd > /dev/null || exit
