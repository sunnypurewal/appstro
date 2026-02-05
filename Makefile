OUTPUT_DIR ?= .build

cli:
	$(MAKE) -C cli build OUTPUT_DIR=$(abspath $(OUTPUT_DIR))

lint:
	swiftlint lint --config .swiftlint.yml

format:
	swiftlint --fix --config .swiftlint.yml

.PHONY: cli lint format
