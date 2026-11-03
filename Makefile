.PHONY: all build bundle dmg test run icon clean

all: bundle

icon:
	./scripts/gen-icons.sh build

build: icon
	./scripts/build.sh

bundle: build

dmg: bundle
	./scripts/make-dmg.sh

test:
	./scripts/test.sh

run: bundle
	open "build/Eye Guardian.app"

clean:
	rm -rf build
