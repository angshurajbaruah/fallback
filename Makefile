APP := build/Build/Products/Debug/Fallback.app

.PHONY: gen build test run install

gen:
	xcodegen generate

build: gen
	xcodebuild -project Fallback.xcodeproj -scheme Fallback -configuration Debug -derivedDataPath build build -quiet -allowProvisioningUpdates

test:
	cd Packages/FallbackCore && swift test

run: build
	-pkill -x Fallback
	open $(APP)

# Release build, signed with the Personal Team, installed to /Applications and started (no Sparkle, notarising or DMG).
INSTALLED := /Applications/Fallback.app

install: gen
	xcodebuild -project Fallback.xcodeproj -scheme Fallback -configuration Release -derivedDataPath build build -quiet -allowProvisioningUpdates
	-pkill -x Fallback
	@while pgrep -x Fallback >/dev/null; do sleep 0.2; done
	rm -rf $(INSTALLED)
	ditto build/Build/Products/Release/Fallback.app $(INSTALLED)
	open $(INSTALLED)
	@echo "Installed and started $(INSTALLED)"
