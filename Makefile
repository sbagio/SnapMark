# SnapMark — Build System
#
# All targets that fetch or use packages MUST run check-deps first.
# This enforces the 7-day supply-chain age gate.

SCHEME        := SnapMark
CONFIGURATION := Release
DERIVED_DATA  := ./build
APP_PATH      := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/$(SCHEME).app
INSTALL_PATH  := /Applications/$(SCHEME).app
MIN_AGE_DAYS  ?= 7

# ── Security gate ──────────────────────────────────────────────────────────

.PHONY: setup
setup:
	@./scripts/setup-signing.sh

.PHONY: check-deps
check-deps:
	@echo ""
	@./scripts/check-package-ages.sh $(MIN_AGE_DAYS)
	@echo ""

# ── Build ──────────────────────────────────────────────────────────────────
# Uses swift build + bundle assembly (no Xcode required).
# The age check is embedded inside build-app.sh.

APP_BUNDLE := ./SnapMark.app

.PHONY: build
build:
	@./scripts/build-app.sh release

.PHONY: build-debug
build-debug:
	@./scripts/build-app.sh debug

# ── Install ────────────────────────────────────────────────────────────────

.PHONY: install
install: build
	rm -rf "$(INSTALL_PATH)"
	cp -r "$(APP_BUNDLE)" "$(INSTALL_PATH)"
	xattr -cr "$(INSTALL_PATH)"
	@echo "Installed to $(INSTALL_PATH)"
	@echo "Grant Screen Recording in System Settings → Privacy & Security"
	@echo "Then restart the app."

.PHONY: run
run: install
	open "$(INSTALL_PATH)"

# ── Package management ─────────────────────────────────────────────────────
# Any Package.swift updates MUST pass the age gate before resolving.

.PHONY: update-packages
update-packages: check-deps
	swift package update

.PHONY: resolve-packages
resolve-packages: check-deps
	swift package resolve

# ── Clean ──────────────────────────────────────────────────────────────────

.PHONY: clean
clean:
	rm -rf $(DERIVED_DATA)
	@echo "Cleaned build artifacts."

.PHONY: uninstall
uninstall:
	rm -rf "$(INSTALL_PATH)"
	@echo "Uninstalled $(SCHEME)."

# ── Help ───────────────────────────────────────────────────────────────────

.PHONY: help
help:
	@echo "SnapMark Build Targets"
	@echo "  make build             — security check → Release build"
	@echo "  make build-debug       — security check → Debug build"
	@echo "  make install           — build + copy to /Applications"
	@echo "  make run               — install + launch"
	@echo "  make check-deps        — run age gate only (MIN_AGE_DAYS=7)"
	@echo "  make update-packages   — age-gated swift package update"
	@echo "  make clean             — remove build artifacts"
	@echo "  make uninstall         — remove from /Applications"
	@echo ""
	@echo "  MIN_AGE_DAYS=14 make build  — stricter: 14-day gate"
