OUTPUT_DIR ?= .build

cli:
	$(MAKE) -C cli build OUTPUT_DIR=$(abspath $(OUTPUT_DIR))

.PHONY: cli
