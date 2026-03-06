.PHONY: build build-release

# Override version at build time (e.g. TAGVER=1.0.0-demo make build-release).
# Writes SnipStash/Version.xcconfig so the app shows this version in About and Info.plist.
TAGVER ?=

build:
	mkdir -p build
	@if [ -n "$(TAGVER)" ]; then \
		printf 'MARKETING_VERSION = %s\nINFOPLIST_KEY_NSHumanReadableCopyright = Copyright © 2026 Centennial OSS\n' "$(TAGVER)" > SnipStash/Version.xcconfig; \
	fi
	xcodebuild -scheme SnipStash -configuration Debug -derivedDataPath build/DerivedData build
	cp -R build/DerivedData/Build/Products/Debug/SnipStash.app build/

build-release:
	mkdir -p dist
	@if [ -n "$(TAGVER)" ]; then \
		printf 'MARKETING_VERSION = %s\nINFOPLIST_KEY_NSHumanReadableCopyright = Copyright © 2026 Centennial OSS\n' "$(TAGVER)" > SnipStash/Version.xcconfig; \
	fi
	xcodebuild -scheme SnipStash -configuration Release -derivedDataPath dist/DerivedData build
	cp -R dist/DerivedData/Build/Products/Release/SnipStash.app dist/
