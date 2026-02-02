OUTPUT_DIR ?= .build

build:
	swift build
	mkdir -p $(OUTPUT_DIR)
	cp $$(swift build --show-bin-path)/appstro $(OUTPUT_DIR)/appstro

run:
	swift run appstro

clean:
	swift package clean

.PHONY: build run clean
