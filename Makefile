.PHONY: all build dmg test run icon clean

all: build

icon:
	swift scripts/build.swift icons

build:
	swift scripts/build.swift build

TEST_PLUGIN_PATH := $(shell dirname "$$(xcrun -f swift-frontend)")/../lib/swift/host/plugins/testing

test:
	swift test --scratch-path build/spm/test \
		-Xswiftc -plugin-path -Xswiftc "$(TEST_PLUGIN_PATH)"

dmg: build
	swift scripts/build.swift dmg

run: build
	open "build/Eye Guardian.app"

clean:
	rm -rf build .build
