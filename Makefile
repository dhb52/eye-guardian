.PHONY: all build bundle test run icon clean

all: bundle

icon:
	@mkdir -p build
	@test -f build/icon-1024.png || swift scripts/gen-icon.swift build/icon-1024.png

build: icon
	./scripts/build.sh

bundle: build

test:
	./scripts/test.sh

run: bundle
	open "build/Eye Guardian.app"

clean:
	rm -rf build
