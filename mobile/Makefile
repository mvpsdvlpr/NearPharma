## Makefile for mobile developer tasks
# Usage:
#   make icons    # regenerate adaptive icon layers and run flutter_launcher_icons
#   make pubget   # run flutter pub get

ICONS_DIR=assets/icons
TOOLS_DIR=tools

.PHONY: icons pubget

icons:
	@echo "Generating adaptive icon layers from $(ICONS_DIR)/icon_master.png..."
	@if [ -f "$(ICONS_DIR)/icon_master.png" ]; then \
	  $(TOOLS_DIR)/generate_icons.sh ../$(ICONS_DIR)/icon_master.png $(ICONS_DIR) || true; \
	else \
	  echo "Warning: $(ICONS_DIR)/icon_master.png not found"; exit 1; \
	fi
	@echo "Running flutter_launcher_icons to generate platform icons..."
	flutter pub get
	flutter pub run flutter_launcher_icons:main

pubget:
	flutter pub get
