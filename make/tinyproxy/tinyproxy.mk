$(call PKG_INIT_BIN, 1.11.0)
$(PKG)_SOURCE:=$(pkg)-$($(PKG)_VERSION).tar.xz
$(PKG)_SOURCE_SHA256:=c1ec81cfc4c551d2c24e0227a5aeeaad8723bd9a39b61cd729e516b82eaa3f32
$(PKG)_SITE:=https://github.com/tinyproxy/tinyproxy/releases/download/$($(PKG)_VERSION)
### WEBSITE:=https://tinyproxy.github.io/
### MANPAGE:=https://tinyproxy.github.io/#documentation
### CHANGES:=https://github.com/tinyproxy/tinyproxy/releases
### CVSREPO:=https://github.com/tinyproxy/tinyproxy

$(PKG)_BINARY:=$($(PKG)_DIR)/src/tinyproxy
$(PKG)_TARGET_BINARY:=$($(PKG)_DEST_DIR)/usr/sbin/tinyproxy

$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_TINYPROXY_WITH_TRANSPARENT_PROXY
$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_TINYPROXY_WITH_FILTER
$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_TINYPROXY_WITH_UPSTREAM
$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_TINYPROXY_WITH_REVERSE
$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_TINYPROXY_STATIC

$(PKG)_CONFIGURE_ENV += tinyproxy_cv_regex_broken=no

$(PKG)_CONFIGURE_OPTIONS += $(if $(FREETZ_PACKAGE_TINYPROXY_WITH_TRANSPARENT_PROXY),--enable-transparent,--disable-transparent)
$(PKG)_CONFIGURE_OPTIONS += $(if $(FREETZ_PACKAGE_TINYPROXY_WITH_FILTER),--enable-filter,--disable-filter)
$(PKG)_CONFIGURE_OPTIONS += $(if $(FREETZ_PACKAGE_TINYPROXY_WITH_UPSTREAM),--enable-upstream,--disable-upstream)
$(PKG)_CONFIGURE_OPTIONS += $(if $(FREETZ_PACKAGE_TINYPROXY_WITH_REVERSE),--enable-reverse,--disable-reverse)
$(PKG)_CONFIGURE_OPTIONS += --disable-manpage-support

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_BINARY): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(TINYPROXY_DIR) $(if $(FREETZ_PACKAGE_TINYPROXY_STATIC),LDFLAGS=-static) V=1

$($(PKG)_TARGET_BINARY): $($(PKG)_BINARY)
	$(INSTALL_BINARY_STRIP)

$(pkg):

$(pkg)-precompiled: $($(PKG)_TARGET_BINARY)

$(pkg)-clean:
	-$(SUBMAKE) -C $(TINYPROXY_DIR) clean
	$(RM) $(TINYPROXY_FREETZ_CONFIG_FILE)

$(pkg)-uninstall:
	$(RM) $(TINYPROXY_TARGET_BINARY)

$(PKG_FINISH)
