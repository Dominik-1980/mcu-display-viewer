#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")"
app_name="MCU Display Viewer.app"
source_app="$project_dir/build/$app_name"
dmg_name="MCU-Display-Viewer-${version}-macOS-Apple-Silicon.dmg"
output_dir="$project_dir/dist"
temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/mcu-display-dmg.XXXXXX")"
volume_dir="$temporary_dir/MCU Display Viewer $version"
mount_dir="$temporary_dir/mount"

cleanup() {
    if mount | grep -Fq " on $mount_dir ("; then
        hdiutil detach -quiet "$mount_dir" || true
    fi
    rm -rf "$temporary_dir"
}
trap cleanup EXIT

if [[ ! -d "$source_app" ]]; then
    print -u2 "App fehlt: $source_app (zuerst ./scripts/build-app.sh ausführen)"
    exit 1
fi

codesign --verify "$source_app"
mkdir -p "$volume_dir" "$output_dir" "$mount_dir"
ditto "$source_app" "$volume_dir/$app_name"
xattr -cr "$volume_dir/$app_name"
codesign --verify --strict "$volume_dir/$app_name"
cp "$project_dir/README.md" "$project_dir/LICENSE" "$volume_dir/"
ln -s /Applications "$volume_dir/Applications"

temporary_dmg="$temporary_dir/$dmg_name"
hdiutil create -quiet -srcfolder "$volume_dir" -volname "MCU Display Viewer $version" -fs HFS+ -format UDZO "$temporary_dmg"
hdiutil verify -quiet "$temporary_dmg"
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mount_dir" "$temporary_dmg"
test -f "$mount_dir/$app_name/Contents/Resources/AppIcon.icns"
test -L "$mount_dir/Applications"
test -f "$mount_dir/LICENSE"
codesign --verify "$mount_dir/$app_name"
hdiutil detach -quiet "$mount_dir"

mv "$temporary_dmg" "$output_dir/$dmg_name"
(cd "$output_dir" && shasum -a 256 "$dmg_name") > "$output_dir/SHA256SUMS"
print -r -- "$output_dir/$dmg_name"
