OUTPUT_DIR ?= .build

cli:
	swift build --product appstro

release:
	swift build -c release --product appstro

clean:
	swift package clean
	rm -rf $(OUTPUT_DIR)

lint:
	swiftlint lint --config .swiftlint.yml

format:
	swiftlint --fix --config .swiftlint.yml

install: release
	cp .build/release/appstro /usr/local/bin/appstro

.PHONY: cli release clean lint format install
