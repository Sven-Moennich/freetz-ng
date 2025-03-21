#!/bin/bash
# Generates a Config.in(.busybox) of Busybox for Freetz
BBDIR="$(dirname $(readlink -f $0))"
[ -z "$1" ] && rm -f $BBDIR/*.?_?? && for x in $(sed -rn 's/^\$\(PKG\)_SOURCE_.*_([0-9\.]{6}*):=.*/\1/p' $BBDIR/busybox.mk); do $0 $x; done && exit
BBVER="${1:-$(sed -n 's/^$(call PKG_INIT_BIN,[^)]*),\([^,]*\),.*/\1/p' $BBDIR/busybox.mk)}"
BBMAJ="${BBVER%.*}"
BBOUT="$BBDIR/Config.in.busybox.${BBMAJ//\./_}"
BBCIN="$BBDIR/Config.in.busybox"
BBSYM="$BBDIR/Config.in.symbools"
BBDEP="$BBDIR/busybox.rebuild-subopts.mk.in"
BBTAG="FREETZ_BUSYBOX___V${BBMAJ//\./}"
echo -n "BusyBox v$BBVER ... "

# supports int/bool/string/choice values
default() {
	sed -r -i '/(^config '${BBTAG}'_'"$1"'$|^[ \t]*prompt "'"$1"'")/,+5 {
		s,(\tdefault )("?)[^"]*\2,\1\2'"$2"'\2,
	}' "$BBOUT"
}

depends_on() {
	sed -i "s/^config ${BBTAG}_${1}$/&\n\tdepends on ${2}/" "$BBOUT"
}

select_() {
	sed -r -i '/^config '${BBTAG}'_'"$1"'$/,/^[ \t]+help$/ {
		/^[ \t]+help$/ i\
	select '"$2"'
	}' "$BBOUT"
}

echo -n "unpacking ..."
rm -rf "$BBDIR/busybox-$BBVER"
[ -e "$HOME/Desktop/busybox-$BBVER.tar.bz2" ] && ARC="$HOME/Desktop/busybox-$BBVER.tar.bz2" || ARC="$BBDIR/../../dl/busybox-$BBVER.tar.bz2"
tar xf "$ARC" -C "$BBDIR" ||  exit 1

echo -n " patching ..."
cd "$BBDIR/busybox-$BBVER/"
for p in $BBDIR/patches/$BBMAJ/*.patch; do
	for l in 0 1 2 3 4 5 6 7 8 9; do
		patch -f -p$l --dry-run < $p &>/dev/null && break || l=0
	done
	patch -p$l < $p >/dev/null
done

echo -n " building ..."
FREETZ_GENERATE_CONFIG_IN_ONLY=y ./scripts/gen_build_files.sh "$BBDIR/busybox-$BBVER/" "$BBDIR/busybox-$BBVER/" >/dev/null

echo -n " parsing ..."
echo -e "\n### Do not edit this file! Run generate.sh to create it. ###\n\n" > "$BBOUT"
$BBDIR/../../tools/parse-config Config.in >> "$BBOUT" 2>/dev/null
rm -rf "$BBDIR/busybox-$BBVER"

echo -n " searching ..."
nonfeature_symbols=""
feature_symbols=""
for symbol in $(sed -n 's/^config //p' "$BBOUT"); do
	if [ "${symbol:0:8}" != "FEATURE_" ]; then
		nonfeature_symbols="${nonfeature_symbols}${nonfeature_symbols:+|}${symbol}"
	else
		feature_symbols="${feature_symbols}${feature_symbols:+|}${symbol}"
	fi
done

echo -n " symbools ..."
echo -e "\n### Do not edit this file! Run generate.sh to create it. ###\n\n" | tee "$BBSYM.${BBMAJ//\./_}" > "$BBSYM"
for x in ${feature_symbols//|/ } ${nonfeature_symbols//|/ }; do
	grep -E "^config $x($| )" "$BBOUT" -A3 | grep -P "^[\t ]*bool" -q && echo "$x"
done | sort >> "$BBSYM.${BBMAJ//\./_}"
grep -vEh '^#|^$' $BBSYM.* | sort -u | while read sym; do
	echo -e "config FREETZ_BUSYBOX_$sym\n\tbool"
	for file in $(grep -l "^$sym$" $BBSYM.*); do
		num="${file##*\.}"
		echo -e "\tselect FREETZ_BUSYBOX___V${num//_/}_$sym if FREETZ_BUSYBOX__VERSION_V${num//_/}"
	done
	echo
done >> "$BBSYM"
# upgrade: sed -r 's/(^#? ?FREETZ_BUSYBOX)_([^_].*)/\1___V1272_\2/g' -i .config

echo -n " replacing ..."
sed -i -r \
	-e "s,([ (!])(${feature_symbols})($|[ )]),\1${BBTAG}_\2\3,g" \
	-e "/^[ \t#]*(config|default|depends|select|range|if)/{
		s,([ (!])(${nonfeature_symbols})($|[ )]),\1${BBTAG}_\2\3,g
		s,([ (!])(${nonfeature_symbols})($|[ )]),\1${BBTAG}_\2\3,g
	}" \
	"$BBOUT"
sed -i '/^mainmenu /d' "$BBOUT"
sed -i 's!\(^#*[\t ]*default \)y\(.*\)$!\1n\2!g;' "$BBOUT"

echo -n " subopts ..."
echo -e "\n### Do not edit this file! Run generate.sh to create it. ###\n\n" | tee "$BBDEP.${BBMAJ//\./_}" | tee "$BBDEP" > "$BBCIN"
sed -n 's/^config /$(PKG)_REBUILD_SUBOPTS += /p' "$BBOUT" | sort -u >> "$BBDEP.${BBMAJ//\./_}"
for file in $BBDEP.*; do
	BBCVN="${file#$BBDEP.}"
	echo -e "ifeq (\$(strip \$(FREETZ_BUSYBOX__VERSION_V${BBCVN/_/})),y)\ninclude \$(MAKE_DIR)/busybox/${file##*/}\nendif\n" >> "$BBDEP"
	echo -e "if FREETZ_BUSYBOX__VERSION_V${BBCVN/_/}\nsource \"make/busybox/Config.in.busybox.${BBCVN}\"\nendif # FREETZ_BUSYBOX__VERSION_V${BBCVN/_/} #\n" >> "$BBCIN"
done

echo -n " defaults ..."
#default UNAME_OSNAME "" # AVM never used the default "GNU/Linux"
default FEATURE_DEFAULT_PASSWD_ALGO 'md5\" if FREETZ_TARGET_UCLIBC_0\n\tdefault \"sha512' # AVM uses the oldest 'des' as default
default SUBST_WCHAR 63
default LAST_SUPPORTED_WCHAR 767
default LAST_SYSTEM_ID 899  # AVM deletes users above default 999
default FEATURE_CROND_DIR "/mod/var/spool/cron"
default "Buffer allocation policy" ${BBTAG}_FEATURE_BUFFERS_USE_MALLOC
depends_on LOCALE_SUPPORT "!FREETZ_TARGET_UCLIBC_0_9_28"
depends_on FEATURE_IPV6 "FREETZ_TARGET_IPV6_SUPPORT"
depends_on KLOGD "FREETZ_AVM_HAS_PRINTK"
depends_on RFKILL "!FREETZ_KERNEL_VERSION_2_6_13"
depends_on FEATURE_MOUNT_NFS "FREETZ_KERNEL_VERSION_2_6_19_MAX"
depends_on FEATURE_INETD_RPC "FREETZ_TARGET_UCLIBC_SUPPORTS_rpc"
depends_on TELNETD "FREETZ_ADD_TELNETD || \(FREETZ_AVM_HAS_TELNETD \&\& !FREETZ_REMOVE_TELNETD\)"
# allow login by telnetd
depends_on FEATURE_NOLOGIN   "!FREETZ_REPLACE_AR7LOGIN"
depends_on FEATURE_SECURETTY "!FREETZ_REPLACE_AR7LOGIN"

depends_on WGET     "!FREETZ_PACKAGE_WGET \|\| FREETZ_WGET_ALWAYS_AVAILABLE"
depends_on XZ       "!FREETZ_PACKAGE_XZ"
depends_on LSOF     "!FREETZ_PACKAGE_LSOF"

# only if nsswitch.conf exists
depends_on USE_BB_PWD_GRP  "FREETZ_AVM_HAS_NSSWITCH"
depends_on USE_BB_SHADOW   "FREETZ_AVM_HAS_NSSWITCH"

# AVM uses KMOD since FOS 7.25 on GRX5 devices
depends_on DEPMOD                             "!FREETZ_PACKAGE_MODULE_INIT_TOOLS_depmod"
depends_on INSMOD   "!FREETZ_AVM_HAS_KMOD \&\& !FREETZ_PACKAGE_MODULE_INIT_TOOLS_insmod"
depends_on LSMOD    "!FREETZ_AVM_HAS_KMOD \&\& !FREETZ_PACKAGE_MODULE_INIT_TOOLS_lsmod"
depends_on MODINFO                            "!FREETZ_PACKAGE_MODULE_INIT_TOOLS_modinfo"
depends_on MODPROBE "!FREETZ_AVM_HAS_KMOD \&\& !FREETZ_PACKAGE_MODULE_INIT_TOOLS_modprobe"
depends_on RMMOD    "!FREETZ_AVM_HAS_KMOD \&\& !FREETZ_PACKAGE_MODULE_INIT_TOOLS_rmmod"
# FEATURE_LSMOD_PRETTY_2_6_OUTPUT is always selected and so MODPROBE_SMALL would cause unmet dependency
depends_on MODPROBE_SMALL "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

# AVM never uses applets, but always binaries.
# Additional tools: ubiblock ubicrc32 ubiformat ubinfo ubinize
# Beside that, ubiattach & ubidetach are enabled (in inhaus all) in AVM's busybox binary
depends_on UBIATTACH    "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
depends_on UBIDETACH    "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
depends_on UBIMKVOL     "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
depends_on UBIRENAME    "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
depends_on UBIRMVOL     "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
depends_on UBIRSVOL     "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
depends_on UBIUPDATEVOL "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
# AVM never uses an applet, but always a binary.
depends_on NANDDUMP     "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

# BUSYBOX_FEATURE_PS_LONG & BUSYBOX_FEATURE_PS_WIDE depends on !DESKTOP.
depends_on DESKTOP "!FREETZ_PATCH_FREETZMOUNT \&\& !FREETZ_PACKAGE_OPENVPN_CGI \&\& !FREETZ_PACKAGE_GW6"
default FEATURE_PS_LONG y
default FEATURE_PS_WIDE y

# header file is missing in 2.6.13
depends_on FEATURE_IP_NEIGH "FREETZ_KERNEL_VERSION_2_6_19_MIN"
depends_on IPNEIGH "FREETZ_KERNEL_VERSION_2_6_19_MIN"

# from-file-to-file mode is supported since 2.6.33
depends_on FEATURE_USE_SENDFILE "FREETZ_KERNEL_VERSION_3_MIN"

# FEATURE_WGET_OPENSSL works only with an openssl binary
#select_ FEATURE_WGET_OPENSSL "FREETZ_PACKAGE_OPENSSL"

# libbusybox is not supported by Freetz
depends_on BUILD_LIBBUSYBOX "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

# Freetz is not Fedora
depends_on FEDORA_COMPAT "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

# Ext*FS
depends_on MKE2FS "!FREETZ_PACKAGE_E2FSPROGS_E2MAKING"
depends_on MKFS_EXT2 "!FREETZ_PACKAGE_E2FSPROGS_E2MAKING"

# used only by freetzmount
depends_on BLKID "FREETZ_PATCH_FREETZMOUNT"

# mdev requires kernel >= 2.6.27 since busybox 1.27.x, see the corresponding note on https://busybox.net/
# and this thread http://lists.busybox.net/pipermail/busybox/2017-March/085362.html for more details
# alternatively we might apply this patch http://busybox.net/0001-mdev-create-devices-from-sys-dev.patch
depends_on MDEV "FREETZ_KERNEL_VERSION_2_6_28_MIN"

# setns syscall is available since kernel 3.0 (s. http://man7.org/linux/man-pages/man2/setns.2.html#VERSIONS)
# and since uclibc-ng 1.0.1 (s. https://github.com/wbx-github/uclibc-ng/commit/5d5c77daae197b00f89ad1517ffb5a7a01a78cff)
depends_on NSENTER "FREETZ_KERNEL_VERSION_3_10_MIN \&\& !FREETZ_AVM_PROP_UCLIBC_0_9_28 \&\& !FREETZ_AVM_PROP_UCLIBC_0_9_29 \&\& !FREETZ_AVM_PROP_UCLIBC_0_9_32"

# fallocate applet requires posix_fallocate which is available (in Freetz) since uClibc-0.9.33
depends_on FALLOCATE FREETZ_TARGET_UCLIBC_0_9_33

depends_on NOMMU "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
# ensure only SH_IS_ASH could be selected
depends_on SH_IS_HUSH "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
depends_on SH_IS_NONE "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
# ensure only BASH_IS_ASH could be selected
depends_on BASH_IS_HUSH "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
depends_on BASH_IS_NONE "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

depends_on FEATURE_PREFER_APPLETS  "FREETZ_BUSYBOX__NOEXEC_NOFORK_OPTIMIZATIONS"
depends_on FEATURE_SH_NOFORK       "FREETZ_BUSYBOX__NOEXEC_NOFORK_OPTIMIZATIONS"
depends_on FEATURE_SH_STANDALONE   "FREETZ_BUSYBOX__NOEXEC_NOFORK_OPTIMIZATIONS"

depends_on FEATURE_USE_BSS_TAIL "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

echo " done."

