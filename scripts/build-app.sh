#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
cd "$repo_dir"

export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/mcu-display-clang-cache"
export SWIFT_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/mcu-display-swift-cache"
scratch_path="${TMPDIR:-/tmp}/mcu-display-spm-build"
cache_path="${TMPDIR:-/tmp}/mcu-display-spm-cache"

xcrun swift build -c release --disable-sandbox --scratch-path "$scratch_path" --cache-path "$cache_path" --manifest-cache local

stage_root="$(mktemp -d "${TMPDIR:-/tmp}/mcu-display-app.XXXXXX")"
trap 'rm -rf "$stage_root"' EXIT
stage_app="$stage_root/MCU Display Viewer.app"
app_path="$repo_dir/build/MCU Display Viewer.app"
mkdir -p "$stage_app/Contents/MacOS" "$stage_app/Contents/Resources" "$repo_dir/build"
cp "$scratch_path/release/MCUDisplay" "$stage_app/Contents/MacOS/MCUDisplay"
cp "$repo_dir/Resources/Info.plist" "$stage_app/Contents/Info.plist"
cp "$repo_dir/Assets/AppIcon.icns" "$stage_app/Contents/Resources/AppIcon.icns"
xattr -cr "$stage_app"
codesign --force --sign - "$stage_app"
codesign --verify --strict "$stage_app"
publish_dir="$(mktemp -d "$repo_dir/build/.mcu-display-publish.XXXXXX")"
next_app="$publish_dir/MCU Display Viewer.app"
backup_app="$publish_dir/previous.app"
ditto "$stage_app" "$next_app"
codesign --verify "$next_app"
if [[ -d "$app_path" ]]; then
    mv "$app_path" "$backup_app"
fi
if mv "$next_app" "$app_path" && codesign --verify "$app_path"; then
    rm -rf "$publish_dir"
else
    rm -rf "$app_path"
    if [[ -d "$backup_app" ]]; then mv "$backup_app" "$app_path"; fi
    exit 1
fi
print -r -- "$app_path"
