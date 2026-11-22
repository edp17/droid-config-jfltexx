#!/bin/bash
# Stage the eight VERIFIED jfltexx camera/media Android-system binaries for the
# Sailfish updater ZIP. This script must run on the build PC, not the phone.
set -euo pipefail

if (( $# != 3 )); then
    echo "Usage: $0 <ANDROID_PRODUCT_DIR> <WORKING_BACKUP_DIR> <IMG_OUT_DIR>" >&2
    echo "Backup directory must contain the verified libstagefright.so and linker." >&2
    exit 2
fi

PRODUCT=$1
BACKUP=$2
IMG_OUT_DIR=$3
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

[ -d "$PRODUCT/system" ] || { echo "Missing Android system output: $PRODUCT/system" >&2; exit 1; }
[ -d "$BACKUP" ] || { echo "Missing verified backup directory: $BACKUP" >&2; exit 1; }
[ -d "$IMG_OUT_DIR" ] || { echo "Missing image output directory: $IMG_OUT_DIR" >&2; exit 1; }
[ -f "$HERE/jfltexx-camera-system-install.sh" ] || {
    echo "Missing companion recovery installer in $HERE" >&2; exit 1;
}

WORK=$(mktemp -d "$IMG_OUT_DIR/.jfltexx-camera.XXXXXXXX")
trap 'rm -rf -- "$WORK"' EXIT

# (Expected SHA256) (relative /system filesystem path) (source on build PC)
# The two differing binaries come from the explicitly verified working device,
# NOT from the currently mismatching HABUILD output.
while read -r digest relative source; do
    [ -n "${digest:-}" ] || continue
    case "$source" in
        PRODUCT:*) from="$PRODUCT/${source#PRODUCT:}" ;;
        BACKUP:*)  from="$BACKUP/${source#BACKUP:}" ;;
        *) echo "Unknown source type: $source" >&2; exit 1 ;;
    esac
    if [ ! -f "$from" ]; then
        echo "Missing camera build input: $from" >&2
        exit 1
    fi
    actual=$(sha256sum "$from")
    actual=${actual%% *}
    if [ "$actual" != "$digest" ]; then
        printf 'SHA256 MISMATCH: %s\n  expected: %s\n  actual:   %s\n' \
            "$from" "$digest" "$actual" >&2
        exit 1
    fi
    mkdir -p -- "$WORK/$(dirname "$relative")"
    cp -- "$from" "$WORK/$relative"
    printf '%s  %s\n' "$digest" "$relative" >> "$WORK/SHA256SUMS"
done <<'FILES'
7871f2dc0ae6bcf1d28188d270cd96c5f7f81e83bd5dddb3fe72ef27ce0e0fac system/vendor/lib/hw/camera.msm8960.so PRODUCT:system/vendor/lib/hw/camera.msm8960.so
a3450728d0fff1744b3b3e73ef7f25e13a665f0d8572f355d440f53a1104d23e system/vendor/lib/camera.device@1.0-impl.jf.so PRODUCT:system/vendor/lib/camera.device@1.0-impl.jf.so
f51f77429f667746aad56c622db47751c813ceb097ad43155bbecc11b039a508 system/vendor/lib/android.hardware.camera.provider@2.4-legacy.jf.so PRODUCT:system/vendor/lib/android.hardware.camera.provider@2.4-legacy.jf.so
18551a89077d93a1d10a49dded27c050606d71c75d085b2767307867bef0e77e system/vendor/lib/hw/android.hardware.camera.provider@2.4-impl.jf.so PRODUCT:system/vendor/lib/hw/android.hardware.camera.provider@2.4-impl.jf.so
ef29deed4c7b8c0777a0ab8f1bcdd2b205c198d58bab1c826ed7fdcc2aca16d5 system/lib/libstagefright.so BACKUP:libstagefright.so
3285ff587f61b5f36063de618582c3f582944f0470bf466d9e89028d3d80b7ca system/bin/mediaextractor PRODUCT:system/bin/mediaextractor
29365016dacca5493dfd2f4498ed46c7932f89f34e809e8e28ba73a3c9026898 system/apex/com.android.media.swcodec/bin/mediaswcodec PRODUCT:system/bin/mediaswcodec
21977adb6c0651b198dff48210f58aae808821ac04807e684527aa4e7e2aafb0 system/apex/com.android.runtime.release/bin/linker BACKUP:linker
FILES

( cd "$WORK" && sha256sum -c SHA256SUMS )

tar -C "$WORK" -cf "$IMG_OUT_DIR/jfltexx-camera-system.tar.tmp" \
    SHA256SUMS system
mv -f -- "$IMG_OUT_DIR/jfltexx-camera-system.tar.tmp" \
    "$IMG_OUT_DIR/jfltexx-camera-system.tar"
cp -- "$HERE/jfltexx-camera-system-install.sh" \
    "$IMG_OUT_DIR/jfltexx-camera-system-install.sh"
chmod 755 "$IMG_OUT_DIR/jfltexx-camera-system-install.sh"

echo "Prepared verified Galaxy S4 Android camera payload:"
ls -lh "$IMG_OUT_DIR/jfltexx-camera-system.tar" \
       "$IMG_OUT_DIR/jfltexx-camera-system-install.sh"
