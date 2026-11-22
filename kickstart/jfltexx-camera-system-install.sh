#!/sbin/sh
# TWRP recovery-side Galaxy S4 i9505 / jfltexx camera compatibility installer.
# Invoked by the existing Sailfish updater-script while /data is mounted.
# Requires the static ARM BusyBox already bundled in the Sailfish ZIP.

BB=/tmp/busybox
ARCHIVE=/tmp/jfltexx-camera-system.tar
WORK=/tmp/jfltexx-camera-system
SYSTEM=/tmp/jfltexx-camera-system-mount
SYSTEM_FILES=
DEVICE=/dev/block/mmcblk0p16
BACKUP=/data/jfltexx-camera-system-originals
MOUNTED=0

say() { echo "jfltexx camera: $*"; }
fail() { say "ERROR: $*" >&2; exit 1; }
cleanup() {
    if [ "$MOUNTED" -eq 1 ]; then
        "$BB" sync
        "$BB" umount "$SYSTEM" || say 'WARNING: cannot unmount temporary system mount'
    fi
}
trap cleanup 0
trap 'exit 1' 1 2 3 15

[ -x "$BB" ] || fail 'Static BusyBox not available at /tmp/busybox'
[ -s "$ARCHIVE" ] || fail 'Camera payload archive missing'
[ -b "$DEVICE" ] || fail "Expected Galaxy S4 system block device missing: $DEVICE"
[ -d /data/.stowaways/sailfishos ] || fail 'Sailfish rootfs is not installed under /data'
"$BB" sha256sum "$ARCHIVE" >/dev/null 2>&1 || \
    fail 'Static BusyBox lacks the sha256sum applet'

"$BB" mkdir -p "$WORK" "$SYSTEM" || fail 'Cannot prepare recovery work directories'
"$BB" tar -xf "$ARCHIVE" -C "$WORK" || fail 'Cannot extract camera archive'

# Validate every staged file BEFORE attempting any /system write.
while read -r expected path; do
    [ -n "$expected" ] || continue
    case "$path" in system/*) ;; *) fail "Unsafe payload path: $path" ;; esac
    src="$WORK/$path"
    [ -f "$src" ] && [ ! -L "$src" ] || fail "Missing staged file: $path"
    actual=$("$BB" sha256sum "$src") || fail "Cannot hash staged file: $path"
    actual=${actual%% *}
    [ "$actual" = "$expected" ] || fail "Wrong SHA256 for staged file: $path"
done <<'FILES'
7871f2dc0ae6bcf1d28188d270cd96c5f7f81e83bd5dddb3fe72ef27ce0e0fac system/vendor/lib/hw/camera.msm8960.so
a3450728d0fff1744b3b3e73ef7f25e13a665f0d8572f355d440f53a1104d23e system/vendor/lib/camera.device@1.0-impl.jf.so
f51f77429f667746aad56c622db47751c813ceb097ad43155bbecc11b039a508 system/vendor/lib/android.hardware.camera.provider@2.4-legacy.jf.so
18551a89077d93a1d10a49dded27c050606d71c75d085b2767307867bef0e77e system/vendor/lib/hw/android.hardware.camera.provider@2.4-impl.jf.so
ef29deed4c7b8c0777a0ab8f1bcdd2b205c198d58bab1c826ed7fdcc2aca16d5 system/lib/libstagefright.so
3285ff587f61b5f36063de618582c3f582944f0470bf466d9e89028d3d80b7ca system/bin/mediaextractor
29365016dacca5493dfd2f4498ed46c7932f89f34e809e8e28ba73a3c9026898 system/apex/com.android.media.swcodec/bin/mediaswcodec
21977adb6c0651b198dff48210f58aae808821ac04807e684527aa4e7e2aafb0 system/apex/com.android.runtime.release/bin/linker
FILES

# Mount the same system partition identified on the working Galaxy S4.
# Keep it separate from whatever mount points TWRP uses internally.
"$BB" mount -t ext4 -o rw "$DEVICE" "$SYSTEM" || \
    fail "Cannot mount $DEVICE read/write"
MOUNTED=1

# Old Android /system partitions have files at their root. Android 10
# system-as-root layouts may instead contain an actual system/ subdirectory.
# Do not assume how recovery/TWRP bind-mounts /system or /system_root.
if [ -f "$SYSTEM/lib/libstagefright.so" ] && \
   [ -f "$SYSTEM/vendor/lib/libmmjpeg.so" ]; then
    SYSTEM_FILES=$SYSTEM
elif [ -d "$SYSTEM/system" ] && [ ! -L "$SYSTEM/system" ] && \
     [ -f "$SYSTEM/system/lib/libstagefright.so" ] && \
     [ -f "$SYSTEM/system/vendor/lib/libmmjpeg.so" ]; then
    SYSTEM_FILES=$SYSTEM/system
else
    fail 'Unknown Android system partition root/layout; refusing to modify it'
fi
say "Android system files located at $SYSTEM_FILES"

# Fail closed on a different ROM layout; do NOT create missing Android/APEX files.
[ -f "$SYSTEM_FILES/build.prop" ] || fail 'Unexpected system partition: no build.prop'
[ -f "$SYSTEM_FILES/apex/com.android.runtime.release/bin/linker" ] || \
    fail 'Unexpected system layout: Runtime APEX linker missing'
[ -f "$SYSTEM_FILES/apex/com.android.media.swcodec/bin/mediaswcodec" ] || \
    fail 'Unexpected system layout: media.swcodec APEX executable missing'

# Preflight ALL target files before any modification. In-place writing preserves
# original ownership, mode and SELinux label of each existing Android file.
while read -r expected path; do
    [ -n "$expected" ] || continue
    relative=${path#system/}
    target="$SYSTEM_FILES/$relative"
    [ -f "$target" ] && [ ! -L "$target" ] || \
        fail "Target missing or symlinked (cannot safely replace): $relative"
done <<'FILES'
7871f2dc0ae6bcf1d28188d270cd96c5f7f81e83bd5dddb3fe72ef27ce0e0fac system/vendor/lib/hw/camera.msm8960.so
a3450728d0fff1744b3b3e73ef7f25e13a665f0d8572f355d440f53a1104d23e system/vendor/lib/camera.device@1.0-impl.jf.so
f51f77429f667746aad56c622db47751c813ceb097ad43155bbecc11b039a508 system/vendor/lib/android.hardware.camera.provider@2.4-legacy.jf.so
18551a89077d93a1d10a49dded27c050606d71c75d085b2767307867bef0e77e system/vendor/lib/hw/android.hardware.camera.provider@2.4-impl.jf.so
ef29deed4c7b8c0777a0ab8f1bcdd2b205c198d58bab1c826ed7fdcc2aca16d5 system/lib/libstagefright.so
3285ff587f61b5f36063de618582c3f582944f0470bf466d9e89028d3d80b7ca system/bin/mediaextractor
29365016dacca5493dfd2f4498ed46c7932f89f34e809e8e28ba73a3c9026898 system/apex/com.android.media.swcodec/bin/mediaswcodec
21977adb6c0651b198dff48210f58aae808821ac04807e684527aa4e7e2aafb0 system/apex/com.android.runtime.release/bin/linker
FILES

# Keep initial Android-base versions on /data, never overwrite prior backups.
# Finish ALL backups successfully before touching a single /system binary.
say 'Backing up original Android camera/media files to /data'
while read -r expected path; do
    [ -n "$expected" ] || continue
    relative=${path#system/}
    target="$SYSTEM_FILES/$relative"
    saved="$BACKUP/$relative"
    "$BB" mkdir -p "${saved%/*}" || fail "Cannot make backup directory for $relative"
    if [ ! -f "$saved" ]; then
        "$BB" cp -p "$target" "$saved" || fail "Cannot back up $relative"
    fi
done <<'FILES'
7871f2dc0ae6bcf1d28188d270cd96c5f7f81e83bd5dddb3fe72ef27ce0e0fac system/vendor/lib/hw/camera.msm8960.so
a3450728d0fff1744b3b3e73ef7f25e13a665f0d8572f355d440f53a1104d23e system/vendor/lib/camera.device@1.0-impl.jf.so
f51f77429f667746aad56c622db47751c813ceb097ad43155bbecc11b039a508 system/vendor/lib/android.hardware.camera.provider@2.4-legacy.jf.so
18551a89077d93a1d10a49dded27c050606d71c75d085b2767307867bef0e77e system/vendor/lib/hw/android.hardware.camera.provider@2.4-impl.jf.so
ef29deed4c7b8c0777a0ab8f1bcdd2b205c198d58bab1c826ed7fdcc2aca16d5 system/lib/libstagefright.so
3285ff587f61b5f36063de618582c3f582944f0470bf466d9e89028d3d80b7ca system/bin/mediaextractor
29365016dacca5493dfd2f4498ed46c7932f89f34e809e8e28ba73a3c9026898 system/apex/com.android.media.swcodec/bin/mediaswcodec
21977adb6c0651b198dff48210f58aae808821ac04807e684527aa4e7e2aafb0 system/apex/com.android.runtime.release/bin/linker
FILES

# All original files exist, and /data backups are complete. Change only the
# content of existing inodes to preserve their owner/mode/SELinux context.
say 'Installing verified Android camera/media fixes'
while read -r expected path; do
    [ -n "$expected" ] || continue
    relative=${path#system/}
    src="$WORK/$path"
    target="$SYSTEM_FILES/$relative"
    current=$("$BB" sha256sum "$target") || fail "Cannot hash $relative"
    current=${current%% *}
    if [ "$current" = "$expected" ]; then
        say "Already correct: $relative"
        continue
    fi
    # Shell redirection truncates the EXISTING inode. It preserves SELinux
    # xattrs and ownership, unlike rename-based replacement on old recovery.
    if ! "$BB" cat "$src" > "$target"; then
        "$BB" cat "$BACKUP/$relative" > "$target" || :
        fail "Write failed for $relative (attempted restore from backup)"
    fi
    current=$("$BB" sha256sum "$target") || fail "Cannot verify $relative"
    current=${current%% *}
    if [ "$current" != "$expected" ]; then
        "$BB" cat "$BACKUP/$relative" > "$target" || :
        fail "Post-write SHA256 mismatch for $relative (attempted restore)"
    fi
    say "Verified: $relative"
done <<'FILES'
7871f2dc0ae6bcf1d28188d270cd96c5f7f81e83bd5dddb3fe72ef27ce0e0fac system/vendor/lib/hw/camera.msm8960.so
a3450728d0fff1744b3b3e73ef7f25e13a665f0d8572f355d440f53a1104d23e system/vendor/lib/camera.device@1.0-impl.jf.so
f51f77429f667746aad56c622db47751c813ceb097ad43155bbecc11b039a508 system/vendor/lib/android.hardware.camera.provider@2.4-legacy.jf.so
18551a89077d93a1d10a49dded27c050606d71c75d085b2767307867bef0e77e system/vendor/lib/hw/android.hardware.camera.provider@2.4-impl.jf.so
ef29deed4c7b8c0777a0ab8f1bcdd2b205c198d58bab1c826ed7fdcc2aca16d5 system/lib/libstagefright.so
3285ff587f61b5f36063de618582c3f582944f0470bf466d9e89028d3d80b7ca system/bin/mediaextractor
29365016dacca5493dfd2f4498ed46c7932f89f34e809e8e28ba73a3c9026898 system/apex/com.android.media.swcodec/bin/mediaswcodec
21977adb6c0651b198dff48210f58aae808821ac04807e684527aa4e7e2aafb0 system/apex/com.android.runtime.release/bin/linker
FILES

"$BB" sync
"$BB" umount "$SYSTEM" || fail 'Cannot unmount Android system partition after camera update'
MOUNTED=0
say 'All eight camera/media Android-system files verified. Installation complete.'
exit 0
