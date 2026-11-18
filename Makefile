APP := build/Build/Products/Debug/Fallback.app

.PHONY: gen build test run

gen:
	xcodegen generate

build: gen
	xcodebuild -project Fallback.xcodeproj -scheme Fallback -configuration Debug -derivedDataPath build build -quiet

test:
	cd Packages/FallbackCore && swift test

run: build
	-pkill -x Fallback
	open $(APP)
