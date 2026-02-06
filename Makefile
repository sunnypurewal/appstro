OUTPUT_DIR ?= .build

cli:
	swift build -c release --product appstro

lint:
	swiftlint lint --config .swiftlint.yml

format:
	swiftlint --fix --config .swiftlint.yml

.PHONY: cli lint format
