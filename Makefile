.PHONY: all build bundle test run icon clean

all: bundle

icon:
	./scripts/gen-icons.sh build

build: icon
	./scripts/build.sh

bundle: build

test:
	./scripts/test.sh

run: bundle
	open "build/Eye Guardian.app"

clean:
	rm -rf build
