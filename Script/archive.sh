#!/bin/bash
set -eo pipefail

MODULE="AEPTestUtils"
CURR_DIR="$(pwd)"

destination_for() {
  local platform=$1 variant=$2
  case "$platform-$variant" in
    ios-device) echo "generic/platform=iOS" ;;
    ios-simulator) echo "generic/platform=iOS Simulator" ;;
    tvos-device) echo "generic/platform=tvOS" ;;
    tvos-simulator) echo "generic/platform=tvOS Simulator" ;;
  esac
}

# AEPTestUtils uses `@testable import AEPCore`/`AEPServices` and references test hooks that
# AEPCore/AEPServices only expose under `#if DEBUG` (e.g. the assignable `EventHub.shared`).
# So the whole graph must be built with testability enabled AND the DEBUG compilation
# condition active; both settings apply to the resolved SPM package dependencies too.
# Without them the archive fails with "Unable to find module dependency" / "cannot assign to
# 'let'" / "inaccessible due to 'private'".
archive_module() {
  local platform=$1
  xcodebuild archive -scheme "$MODULE" -archivePath "./build/$MODULE-$platform.xcarchive" -destination "$(destination_for "$platform" device)" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES ENABLE_TESTABILITY=YES SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG
  xcodebuild archive -scheme "$MODULE" -archivePath "./build/$MODULE-${platform}_simulator.xcarchive" -destination "$(destination_for "$platform" simulator)" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES ENABLE_TESTABILITY=YES SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG
}

build_platform() {
  local platform=$1
  # AEPTestUtils.xcodeproj / .xcworkspace and Package.swift coexisting makes xcodebuild's
  # scheme resolution ambiguous, so the legacy project is moved aside for the build.
  mv AEPTestUtils.xcodeproj .AEPTestUtils.xcodeproj.bak
  mv AEPTestUtils.xcworkspace .AEPTestUtils.xcworkspace.bak
  trap 'mv .AEPTestUtils.xcodeproj.bak AEPTestUtils.xcodeproj; mv .AEPTestUtils.xcworkspace.bak AEPTestUtils.xcworkspace' EXIT
  archive_module "$platform"
}

create_xcframeworks() {
  local include_tvos=$1
  args=(
    -framework "./build/$MODULE-ios_simulator.xcarchive/Products/usr/local/lib/$MODULE.framework"
    -debug-symbols "$CURR_DIR/build/$MODULE-ios_simulator.xcarchive/dSYMs/$MODULE.framework.dSYM"
  )
  if [ "$include_tvos" = "true" ]; then
    args+=(
      -framework "./build/$MODULE-tvos_simulator.xcarchive/Products/usr/local/lib/$MODULE.framework"
      -debug-symbols "$CURR_DIR/build/$MODULE-tvos_simulator.xcarchive/dSYMs/$MODULE.framework.dSYM"
    )
  fi
  args+=(
    -framework "./build/$MODULE-ios.xcarchive/Products/usr/local/lib/$MODULE.framework"
    -debug-symbols "$CURR_DIR/build/$MODULE-ios.xcarchive/dSYMs/$MODULE.framework.dSYM"
  )
  if [ "$include_tvos" = "true" ]; then
    args+=(
      -framework "./build/$MODULE-tvos.xcarchive/Products/usr/local/lib/$MODULE.framework"
      -debug-symbols "$CURR_DIR/build/$MODULE-tvos.xcarchive/dSYMs/$MODULE.framework.dSYM"
    )
  fi
  args+=(-output "./build/$MODULE.xcframework")
  xcodebuild -create-xcframework "${args[@]}"
}

case "$1" in
  build-ios) build_platform ios ;;
  build-tvos) build_platform tvos ;;
  create-xcframeworks) create_xcframeworks true ;;
  create-xcframeworks-ios) create_xcframeworks false ;;
  *) echo "Usage: $0 {build-ios|build-tvos|create-xcframeworks|create-xcframeworks-ios}" >&2; exit 1 ;;
esac
