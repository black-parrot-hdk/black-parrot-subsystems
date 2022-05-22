.PHONY: all clean

TEMPLATE_DIR := ../template
PLATFORM_RTL_DIR := ./rtl
WORK_DIR := ./work
PATCH_FILE := zedboard.patch
all:
	mkdir -p $(WORK_DIR)
	cp $(TEMPLATE_DIR)/* $(WORK_DIR)/
	cp $(PLATFORM_RTL_DIR)/* $(WORK_DIR)/
	patch -ud $(WORK_DIR) < $(PATCH_FILE)
clean:
	rm -rf $(WORK_DIR)
