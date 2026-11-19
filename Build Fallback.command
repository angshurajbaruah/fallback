#!/bin/zsh
# Double-click to build Fallback from this folder, sign it with your own free Apple ID
# (Personal Team), install it in /Applications and start it.
# It stops with a plain-English message at the first thing that's missing.

cd "${0:A:h}" || exit 1
LOG="$PWD/build/build-log.txt"
OWNER_TEAM="YM6Q5VGJZK" # the project's own team keeps its bundle ID

step() { print "\n▸ $1" }
ok()   { print "  ✓ $1" }
stop() {
  print "\n✋ $1"
  print "\nWhen that's done, double-click \"Build Fallback.command\" again.\n"
  exit 1
}

print "Building Fallback on this Mac. The first time takes a few minutes."

# 1. Xcode: installed, opened once, licence accepted.
step "Checking Xcode"
XCODE=""
[[ -d /Applications/Xcode.app ]] && XCODE=/Applications/Xcode.app
[[ -z $XCODE ]] && XCODE=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null | head -1)
[[ -z $XCODE ]] && stop "Xcode isn't installed.
   Open the App Store, search for \"Xcode\", and click Get. It's free but large (about 10 GB),
   so give it time. Then open Xcode once from your Applications folder."
# Use that Xcode even if the Mac is set to the smaller Command Line Tools.
export DEVELOPER_DIR="$XCODE/Contents/Developer"
xcodebuild -license check >/dev/null 2>&1 || stop "Xcode's licence hasn't been accepted yet.
   Open Xcode from your Applications folder and click Agree when it asks."
xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1 || stop "Xcode hasn't finished setting itself up.
   Open Xcode from your Applications folder and let it install its components (click Install
   if it asks). You can close it once its welcome window appears."
ok "$(xcodebuild -version 2>/dev/null | head -1)"

# 2. Homebrew, then XcodeGen (it writes the Xcode project from project.yml).
step "Checking Homebrew"
for brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [[ -x $brew ]] && { eval "$($brew shellenv)"; break }
done
command -v brew >/dev/null || stop "Homebrew isn't installed. It's a free installer for developer tools.
   1. Go to https://brew.sh and copy the line under \"Install Homebrew\".
   2. Open Terminal (Applications › Utilities › Terminal), paste the line and press Return.
   3. Type your Mac password when asked (nothing shows as you type; that's normal).
   4. When it finishes, close Terminal."
ok "Homebrew"
if ! command -v xcodegen >/dev/null; then
  print "  Installing XcodeGen (one time)…"
  brew install xcodegen || stop "Homebrew couldn't install XcodeGen. Check your internet connection."
fi
ok "XcodeGen"

# 3. An Apple ID in Xcode, which gives you a free Personal Team to sign with.
step "Checking your Apple ID in Xcode"
TEAMS=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null)
# Prefer the free Personal Team; otherwise the first team listed.
TEAM=$(print -r -- "$TEAMS" | awk '/isFreeProvisioningTeam = 1/ {free=1} /teamID =/ {gsub(/[ ;"]/,"",$3); if (free) {print $3; exit} if (!first) first=$3} END {if (!free && first) print first}' | head -1)
[[ -z $TEAM ]] && stop "Xcode doesn't know your Apple ID yet.
   1. Open Xcode, then choose Xcode › Settings… (top-left menu) › Accounts.
   2. Click + at the bottom left, choose Apple ID and sign in. A free Apple ID is enough.
   3. Close the Settings window."
ok "Signing with team $TEAM"

# Apple won't give one bundle ID to two teams, so anyone else's copy gets its own.
if [[ $TEAM == $OWNER_TEAM ]]; then
  BUNDLE_ID="com.angshurajbaruah.fallback"
else
  BUNDLE_ID="local.fallback.${TEAM:l}"
fi

# 4. Build in Release, signed with that team.
step "Building (a few minutes)"
mkdir -p build
xcodegen generate --quiet >"$LOG" 2>&1 || stop "XcodeGen couldn't create the project. Details are in build/build-log.txt."
if ! xcodebuild -project Fallback.xcodeproj -scheme Fallback -configuration Release -derivedDataPath build build \
     -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" >>"$LOG" 2>&1; then
  if grep -q -i -E "signing|provisioning|certificate|development team|No Account" "$LOG"; then
    stop "Xcode couldn't sign Fallback with your Apple ID.
   Open Xcode › Settings… › Accounts, select your Apple ID and check it says \"Personal Team\".
   If it shows an error, sign out and back in. Details are in build/build-log.txt."
  fi
  print "\nLast lines of the build log:"; tail -15 "$LOG"
  stop "The build failed. The full log is in build/build-log.txt (in this folder).
   If you report it on GitHub, attach that file."
fi
ok "Built"

# 5. Install to /Applications and start it.
step "Installing to /Applications"
[[ -w /Applications ]] || stop "This Mac account can't add apps to /Applications.
   Log in as an administrator, or ask one to run this file."
pkill -x Fallback 2>/dev/null
while pgrep -x Fallback >/dev/null; do sleep 0.2; done
rm -rf /Applications/Fallback.app
ditto build/Build/Products/Release/Fallback.app /Applications/Fallback.app || stop "Couldn't copy Fallback into /Applications."
ok "Installed /Applications/Fallback.app"
open /Applications/Fallback.app

print "\n✅ Fallback is running. Look for its icon in the menu bar at the top of the screen."
print "   The first time, a short setup walks you through the one permission it needs."
print "   To update later, download the new code and double-click this file again.\n"
print "You can close this window."
