# TodoApp Makefile
# Convenient build targets for the TodoApp macOS application

.PHONY: help build run clean dmg dmg-quick dmg-version test install open-dmg

# Default target
.DEFAULT_GOAL := help

# Variables
APP_NAME = TodoApp
XCODE_PROJECT = $(APP_NAME).xcodeproj
BUILD_DIR = build
DIST_DIR = dist
APP_PATH = $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app
DMG_PATH = $(DIST_DIR)/$(APP_NAME).dmg

help: ## Show this help message
	@echo "TodoApp Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the app in Release configuration
	@echo "Building $(APP_NAME)..."
	@xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(APP_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		clean build \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		| grep -E '(error|warning|Building|Succeeded|Failed)' || true

build-debug: ## Build the app in Debug configuration
	@echo "Building $(APP_NAME) (Debug)..."
	@xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(APP_NAME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		build \
		| grep -E '(error|warning|Building|Succeeded|Failed)' || true

run: build-debug ## Build and run the app
	@echo "Launching $(APP_NAME)..."
	@open $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app

clean: ## Clean build artifacts and DMG files
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(DIST_DIR)
	@echo "Clean complete"

dmg: ## Create a distributable DMG with styling
	@./scripts/make-dmg.sh

dmg-quick: ## Create a DMG without styling (faster)
	@./scripts/quick-dmg.sh

dmg-version: ## Create a versioned DMG (usage: make dmg-version VERSION=1.0.0)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION not specified. Usage: make dmg-version VERSION=1.0.0"; \
		exit 1; \
	fi
	@./scripts/make-dmg.sh --version $(VERSION)

dmg-skip-build: ## Create DMG using existing build
	@./scripts/make-dmg.sh --skip-build

open-dmg: ## Open the generated DMG file
	@if [ -f "$(DMG_PATH)" ]; then \
		open $(DMG_PATH); \
	else \
		echo "Error: DMG not found at $(DMG_PATH)"; \
		echo "Run 'make dmg' first to create the DMG"; \
		exit 1; \
	fi

install: dmg ## Build DMG and open it for installation
	@open $(DMG_PATH)

test: ## Run tests (if available)
	@xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(APP_NAME) \
		-configuration Debug \
		test || echo "No tests configured"

info: ## Show project information
	@echo "Project: $(APP_NAME)"
	@echo "Xcode Project: $(XCODE_PROJECT)"
	@echo "Build Directory: $(BUILD_DIR)"
	@echo "Distribution Directory: $(DIST_DIR)"
	@echo ""
	@if [ -d "$(APP_PATH)" ]; then \
		echo "App Version: $$(defaults read "$(APP_PATH)/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo 'unknown')"; \
		echo "App Build: $$(defaults read "$(APP_PATH)/Contents/Info" CFBundleVersion 2>/dev/null || echo 'unknown')"; \
	else \
		echo "App not built yet. Run 'make build' first."; \
	fi

archive: dmg ## Create DMG and archive with timestamp
	@TIMESTAMP=$$(date +%Y%m%d-%H%M%S); \
	ARCHIVE_NAME="$(APP_NAME)-$$TIMESTAMP.dmg"; \
	cp $(DMG_PATH) $(DIST_DIR)/$$ARCHIVE_NAME; \
	echo "Archived as $(DIST_DIR)/$$ARCHIVE_NAME"

release: clean dmg ## Clean build and create release DMG
	@echo "Release build complete!"
	@ls -lh $(DMG_PATH)

.PHONY: build-debug run clean dmg dmg-quick dmg-version dmg-skip-build open-dmg install test info archive release
