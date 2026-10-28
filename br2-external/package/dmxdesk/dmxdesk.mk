################################################################################
#
# dmxdesk
#
################################################################################

DMXDESK_VERSION = v0.1.10
DMXDESK_SITE = $(call github,spectalive,dmxdesk,$(DMXDESK_VERSION))
DMXDESK_LICENSE = GPL-2.0+ (dmxdesk), MIT (cJSON)
DMXDESK_LICENSE_FILES = LICENSE cJSON.c
DMXDESK_DEPENDENCIES = libdrm stb taq102-fonts
# Same pinned cJSON as the standalone build, compiled into the executable: no
# new runtime .so for old ramdisks.
DMXDESK_CJSON_VERSION = 1.7.19
DMXDESK_EXTRA_DOWNLOADS = \
	https://raw.githubusercontent.com/DaveGamble/cJSON/v$(DMXDESK_CJSON_VERSION)/cJSON.c \
	https://raw.githubusercontent.com/DaveGamble/cJSON/v$(DMXDESK_CJSON_VERSION)/cJSON.h

define DMXDESK_COPY_CJSON
	mkdir -p $(@D)/include/cjson
	cp $(DMXDESK_DL_DIR)/cJSON.h $(@D)/include/cjson/
	cp $(DMXDESK_DL_DIR)/cJSON.c $(@D)/
endef
DMXDESK_POST_EXTRACT_HOOKS += DMXDESK_COPY_CJSON
# A checkout given as DMXDESK_OVERRIDE_SRCDIR is rsynced, not extracted: it
# needs the same cJSON, from the download cache of an earlier build.
DMXDESK_POST_RSYNC_HOOKS += DMXDESK_COPY_CJSON
# The checkout's own output/ holds host builds and captures, not sources.
DMXDESK_OVERRIDE_SRCDIR_RSYNC_EXCLUSIONS = --exclude output

# Releases up to v0.1.10 keep everything in src/ with a bare source list;
# from the core/platform split (2026-10-27) the list is dmxdesk.sources at the
# root with paths, and the headers sit in core/ and platform/linux-fb/.
define DMXDESK_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -O2 -w -c $(@D)/cJSON.c -I$(@D)/include/cjson -o $(@D)/cJSON.o
	if [ -f $(@D)/dmxdesk.sources ]; then \
		inc="-I$(@D)/core -I$(@D)/platform/linux-fb"; \
		srcs=`sed 's|^|$(@D)/|' $(@D)/dmxdesk.sources`; \
	else \
		inc="-I$(@D)/src"; \
		srcs=`sed 's|^|$(@D)/src/|' $(@D)/src/dmxdesk.sources`; \
	fi; \
	$(TARGET_CC) $(TARGET_CFLAGS) -std=gnu99 -Wall -Wextra -Werror -O2 \
		$$inc -I$(@D)/include -I$(STAGING_DIR)/usr/include/libdrm \
		-o $(@D)/dmxdesk $$srcs \
		$(@D)/cJSON.o $(TARGET_LDFLAGS) -ldrm -lm -pthread
endef

define DMXDESK_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/dmxdesk $(TARGET_DIR)/usr/bin/dmxdesk
	$(INSTALL) -D -m 0644 $(@D)/show/vibra.desk.json $(TARGET_DIR)/usr/share/dmxdesk/vibra.desk.json
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_TAQ102_PATH)/package/dmxdesk/taq102-desk \
		$(TARGET_DIR)/usr/bin/taq102-desk
endef

$(eval $(generic-package))
