OUTPUT_DIR ?= .build

build:
	swift build --scratch-path $(OUTPUT_DIR)
	mkdir -p $(OUTPUT_DIR)
	cp $$(swift build --scratch-path $(OUTPUT_DIR) --show-bin-path)/appstro $(OUTPUT_DIR)/appstro

release:
	swift build -c release --scratch-path $(OUTPUT_DIR) -Xswiftc -lto=llvm-full
	mkdir -p $(OUTPUT_DIR)
	cp $$(swift build -c release --scratch-path $(OUTPUT_DIR) --show-bin-path)/appstro $(OUTPUT_DIR)/appstro
	strip $(OUTPUT_DIR)/appstro
	rm -f *.bc

install: release
	mkdir -p /usr/local/bin
	cp $(OUTPUT_DIR)/appstro /usr/local/bin/appstro

run:
	swift run appstro

clean:
	swift package clean

.PHONY: build release install run clean
