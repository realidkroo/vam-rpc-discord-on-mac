

#!/bin/bash
set -e

APP_NAME="VAM-RPC"
SWIFT_SOURCES=(
    "Swift/main.swift" 
    "Swift/AppDelegate.swift" 
    "Swift/PreferencesViewController.swift"
    "Swift/SettingsModel.swift"
    "Swift/ConfigManager.swift"
    "Swift/ModernComponents.swift"
   #"Swift/ModernWindow.swift"  
    "Swift/Sidebar.swift"
    "Swift/FloatingPill.swift"
    "Swift/HomeVC.swift"
    "Swift/SmartPreview.swift"
    "Swift/RPCSettingsVC.swift"
    "Swift/ExperimentalVC.swift"
    "Swift/ModernPreferencesVC.swift"
)
AGENT_SCRIPT="agent.ts"
ICON_SOURCE="icon/icon.png"
DIST_DIR="build_result"

REQUIRED_ASSETS=(
    "icon/icon.png"
    "icon/asltolfo.png"
    "icon/roo.jpg"
)

dots_array=("." ".." "...")
spinner_index=0
rows=$(tput lines)
update_progress() {
    local current_step=$1
    local total_steps=$2
    local message="$3"
    local dots=${dots_array[$((spinner_index % ${#dots_array[@]}))]}
    spinner_index=$((spinner_index + 1))
    local percent=$((current_step * 100 / total_steps))
    local filled_len=$((percent * 25 / 100))
    local bar=$(printf "%*s" "$filled_len" | tr ' ' '█')
    local empty=$(printf "%*s" $((25 - filled_len)) | tr ' ' '░')
    tput cup $((rows - 1)) 0
    printf "\033[K"
    printf "[ %s ] [%s%s] %3d%%%s" "$message" "$bar" "$empty" "$percent" "$dots"
}

build_for_arch() {
    local ARCH_NAME=$1
    local SWIFT_TARGET=$2
    local OUTPUT_DIR="$DIST_DIR/$ARCH_NAME"
    local APP_BUNDLE_PATH="$OUTPUT_DIR/$APP_NAME.app"
    local CONTENTS_PATH="$APP_BUNDLE_PATH/Contents"
    local MACOS_PATH="$CONTENTS_PATH/MacOS"
    local RESOURCES_PATH="$CONTENTS_PATH/Resources"
    mkdir -p "$MACOS_PATH" "$RESOURCES_PATH"
    
    cp -R "icon.iconset" "$RESOURCES_PATH/"
    iconutil -c icns "$RESOURCES_PATH/icon.iconset" -o "$RESOURCES_PATH/AppIcon.icns" &>/dev/null

    cat > "$CONTENTS_PATH/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>$APP_NAME</string><key>CFBundleIconFile</key><string>AppIcon.icns</string><key>CFBundleIdentifier</key><string>com.vam-rpc.app</string><key>LSMinimumSystemVersion</key><string>11.0</string><key>LSUIElement</key><false/></dict></plist>
EOF
    swiftc -suppress-warnings -o "$MACOS_PATH/$APP_NAME" $SWIFT_TARGET -sdk "$(xcrun --show-sdk-path)" -framework Cocoa "${SWIFT_SOURCES[@]}"
    cp "$AGENT_SCRIPT" "$RESOURCES_PATH/"
    cp -R "data" "$RESOURCES_PATH/"
    

    cp "icon/asltolfo.png" "$RESOURCES_PATH/"
    cp "icon/roo.jpg" "$RESOURCES_PATH/"
}

# Attempt to quit any running instances of the built app.
# First tries a graceful quit via AppleScript, then falls back to pkill.
kill_running_instances() {
    echo "Checking for running $APP_NAME instances..."

    # Detect likely running processes: exact executable name or .app bundle
    if pgrep -x "$APP_NAME" >/dev/null 2>&1 || pgrep -f "$APP_NAME.app" >/dev/null 2>&1; then
        # Try a graceful quit via AppleScript (if available)
        if command -v osascript >/dev/null 2>&1; then
            osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
            sleep 1
        fi

        # Force-kill any remaining processes that match the name or bundle
        pkill -f "$APP_NAME" >/dev/null 2>&1 || true
        pkill -f "$APP_NAME.app" >/dev/null 2>&1 || true

        echo "Killed running $APP_NAME instances."
    else
        echo "No running $APP_NAME instances found."
    fi
}

# Open the built app that matches the host architecture.
open_app_for_host() {
    local host_arch
    host_arch=$(uname -m)
    local target_dir
    if [ "$host_arch" = "arm64" ]; then
        target_dir="$DIST_DIR/Apple Silicon"
    else
        target_dir="$DIST_DIR/Intel"
    fi

    local app_path="$target_dir/$APP_NAME.app"
    if [ -d "$app_path" ]; then
        echo "Opening $APP_NAME for host architecture ($host_arch)..."
        open "$app_path" >/dev/null 2>&1 || true
    else
        echo "Warning: built app not found at '$app_path' — not opening." >&2
    fi
}


trap 'tput cnorm; exit' INT TERM
tput civis
echo ""
echo "Build is started, yay! >_< "
echo "Do not interupt"
echo ""

for asset_path in "${REQUIRED_ASSETS[@]}"; do
    if [ ! -f "$asset_path" ]; then
        echo -e "\n\n❌ FATAL: Required asset not found at '$asset_path'." >&2
        tput cnorm; exit 1
    fi
done
echo "All image assets found."
echo ""

total_steps=4
update_progress 0 $total_steps "Preparing environment..."
(
    rm -rf "$DIST_DIR" "icon.iconset"
    mkdir -p "icon.iconset"
    # Convert ic
    sips -z 1024 1024 "icon/icon.png" --out "icon.iconset/icon_512x512@2x.png" &>/dev/null
) &
pid=$!
while kill -0 $pid 2>/dev/null; do sleep 0.3; update_progress 0 $total_steps "Preparing environment..."; done
wait $pid || exit $?

update_progress 1 $total_steps "Building for Intel Macs..."
( build_for_arch "Intel" "-target x86_64-apple-macos11" ) &
pid=$!
while kill -0 $pid 2>/dev/null; do sleep 0.3; update_progress 1 $total_steps "Building for Intel Macs..."; done
wait $pid || exit $?

update_progress 2 $total_steps "Building for Apple Silicon Macs..."
( build_for_arch "Apple Silicon" "-target arm64-apple-macos11" ) &
pid=$!
while kill -0 $pid 2>/dev/null; do sleep 0.3; update_progress 2 $total_steps "Building for Apple Silicon Macs..."; done
wait $pid || exit $?

update_progress 3 $total_steps "Cleaning up temporary files..."
( rm -rf "icon.iconset" ) &
pid=$!
while kill -0 $pid 2>/dev/null; do sleep 0.3; update_progress 3 $total_steps "Cleaning up temporary files..."; done
wait $pid || exit $?

update_progress 4 $total_steps "Successfully compiled both versions!"
tput cnorm
echo ""
echo ""
echo "##########################################"
echo "# Build successful in folder $DIST_DIR :)"
echo "##########################################"
echo ""
# After a successful build, attempt to quit any running instances so the
# freshly built app can be launched without conflicts.
kill_running_instances

# After killing old instances, open the newly built app for this machine's
# architecture so you can test immediately.
open_app_for_host