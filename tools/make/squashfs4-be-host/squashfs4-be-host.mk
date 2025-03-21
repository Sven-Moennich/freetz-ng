$(call TOOL_INIT, 4.3)
$(TOOL)_SOURCE:=squashfs$($(TOOL)_VERSION).tar.gz
$(TOOL)_SOURCE_MD5:=d92ab59aabf5173f2a59089531e30dbf
$(TOOL)_SITE:=@SF/squashfs

# Enable legacy SquashFS formats support (SquashFS-1/2/3, ZLIB/LZMA1 compressed)
# 1 - to enable
# 0 - to disable
$(TOOL)_ENABLE_LEGACY_FORMATS_SUPPORT:=1

$(TOOL)_BUILD_DIR:=$($(TOOL)_DIR)/squashfs-tools

$(TOOL)_TOOLS:=mksquashfs unsquashfs
$(TOOL)_TOOLS_BUILD_DIR:=$(addprefix $($(TOOL)_BUILD_DIR)/,$($(TOOL)_TOOLS))
$(TOOL)_TOOLS_TARGET_DIR:=$($(TOOL)_TOOLS:%=$(TOOLS_DIR)/%4-avm-be)


$(tool)-source: $(DL_DIR)/$($(TOOL)_SOURCE)
#
$(DL_DIR)/$($(TOOL)_SOURCE): | $(DL_DIR)
	$(DL_TOOL) $(DL_DIR) $(SQUASHFS4_BE_HOST_SOURCE) $(SQUASHFS4_BE_HOST_SITE) $(SQUASHFS4_BE_HOST_SOURCE_MD5)
#

$(tool)-unpacked: $($(TOOL)_DIR)/.unpacked
$($(TOOL)_DIR)/.unpacked: $(DL_DIR)/$($(TOOL)_SOURCE) | $(TOOLS_SOURCE_DIR) $(UNPACK_TARBALL_PREREQUISITES)
	mkdir -p $(SQUASHFS4_BE_HOST_DIR)
	$(call UNPACK_TARBALL,$(DL_DIR)/$(SQUASHFS4_BE_HOST_SOURCE),$(SQUASHFS4_BE_HOST_DIR),1)
	$(call APPLY_PATCHES,$(SQUASHFS4_BE_HOST_MAKE_DIR)/patches,$(SQUASHFS4_BE_HOST_DIR))
	touch $@

$($(TOOL)_TOOLS_BUILD_DIR): $($(TOOL)_DIR)/.unpacked $(LZMA2_HOST_DIR)/liblzma.a
	$(TOOL_SUBMAKE) -C $(SQUASHFS4_BE_HOST_BUILD_DIR) \
		CC="$(TOOLS_CC)" \
		CXX="$(TOOLS_CXX)" \
		EXTRA_CFLAGS="-fcommon -DTARGET_FORMAT=AVM_BE" \
		EXTRA_LDFLAGS="" \
		LEGACY_FORMATS_SUPPORT=$(SQUASHFS4_BE_HOST_ENABLE_LEGACY_FORMATS_SUPPORT) \
		GZIP_SUPPORT=$(SQUASHFS4_BE_HOST_ENABLE_LEGACY_FORMATS_SUPPORT) \
		LZMA_XZ_SUPPORT=$(SQUASHFS4_BE_HOST_ENABLE_LEGACY_FORMATS_SUPPORT) \
		XZ_SUPPORT=1 \
		XZ_DIR="$(abspath $(LZMA2_HOST_DIR))" \
		COMP_DEFAULT=xz \
		XATTR_SUPPORT=0 \
		XATTR_DEFAULT=0 \
		$(SQUASHFS4_BE_HOST_TOOLS)
	touch -c $@

$($(TOOL)_TOOLS_TARGET_DIR): $(TOOLS_DIR)/%4-avm-be: $($(TOOL)_BUILD_DIR)/%
	$(INSTALL_FILE)

$(tool)-precompiled: $($(TOOL)_TOOLS_TARGET_DIR)


$(tool)-clean:
	-$(MAKE) -C $(SQUASHFS4_BE_HOST_BUILD_DIR) clean

$(tool)-dirclean:
	$(RM) -r $(SQUASHFS4_BE_HOST_DIR)

$(tool)-distclean: $(tool)-dirclean
	$(RM) $(SQUASHFS4_BE_HOST_TOOLS_TARGET_DIR)

$(TOOL_FINISH)
