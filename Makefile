.PHONY: all build dmg test run icon clean

all: build

icon:
	swift scripts/build.swift icons

build:
	swift scripts/build.swift build

# The Command Line Tools ship the swift-testing plugin and framework outside the paths SwiftPM
# searches, so the test run needs both pointed at explicitly. Their Foundation cross-import
# overlay is a stub without modules, so the overlay lookup has to be turned off as well.
TOOLCHAIN := $(shell dirname $$(dirname $$(dirname $(shell xcrun -f swift-frontend))))
TEST_PLUGIN_PATH := $(wildcard $(TOOLCHAIN)/usr/lib/swift/host/plugins/testing)
TEST_FRAMEWORKS := $(wildcard $(TOOLCHAIN)/Library/Developer/Frameworks)

TEST_FLAGS := $(if $(TEST_PLUGIN_PATH),-Xswiftc -plugin-path -Xswiftc $(TEST_PLUGIN_PATH)) \
	$(if $(TEST_FRAMEWORKS),-Xswiftc -F -Xswiftc $(TEST_FRAMEWORKS) \
		-Xlinker -F -Xlinker $(TEST_FRAMEWORKS) \
		-Xlinker -rpath -Xlinker $(TEST_FRAMEWORKS) \
		-Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays)

test:
	swift test --scratch-path build/spm/test $(TEST_FLAGS)

dmg: build
	swift scripts/build.swift dmg

run: build
	open "build/Eye Guardian.app"

clean:
	rm -rf build .build
