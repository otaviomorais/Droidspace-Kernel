#!/bin/bash

source settings.sh

#
# Droidspace Kernel build script
# Adapted from TIMISONG-dev/MagicTime kernel build.sh
#

KERNEL=$PWD
KERNEL_SOURCE=$KERNEL/kernel_source

CLANG=$KERNEL/toolchains/clang
GCC_ARM=$KERNEL/toolchains/arm-linux-androideabi-4.9
GCC_AARCH64=$KERNEL/toolchains/aarch64-linux-android-4.9

CLANG_LINK="https://github.com/ZyCromerZ/Clang/releases/download/20.0.0git-20250129-release/Clang-20.0.0git-20250129.tar.gz"
GCC_ARM_LINK="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9"
GCC_AARCH64_LINK="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9"
KERNEL_REPO="https://github.com/starscroch/kernel_xiaomi_sm8250.git"
KERNEL_BRANCH="lineage-sunflower"
ANYKERNEL_LINK="https://github.com/TIMISONG-dev/MagicTime-alioth"
ANYKERNEL_DIR=$KERNEL/AnyKernel

setup_toolchains() {
    echo "=== Setting up toolchains ==="

    if [ ! -d $CLANG ]; then
        echo "Downloading Clang..."
        mkdir -p $CLANG
        cd $CLANG
        wget -q -O clang.tar.gz $CLANG_LINK
        tar -zxf clang.tar.gz --strip-components=1
        rm -f clang.tar.gz
        cd $KERNEL
    fi

    if [ ! -d $GCC_ARM ]; then
        echo "Downloading GCC ARM..."
        git clone --depth=1 $GCC_ARM_LINK $GCC_ARM
    fi

    if [ ! -d $GCC_AARCH64 ]; then
        echo "Downloading GCC AARCH64..."
        git clone --depth=1 $GCC_AARCH64_LINK $GCC_AARCH64
    fi

    export PATH=$CLANG/bin:$GCC_AARCH64/bin:$GCC_ARM/bin:$PATH
}

clone_kernel() {
    echo "=== Cloning kernel source (${KERNEL_REPO} - branch: ${KERNEL_BRANCH}) ==="
    if [ ! -d $KERNEL_SOURCE ]; then
        git clone --depth=1 --recursive -b $KERNEL_BRANCH $KERNEL_REPO $KERNEL_SOURCE
        cd $KERNEL_SOURCE
        git submodule update --init --recursive 2>/dev/null || true
        if [ ! -f KernelSU/kernel/Makefile ]; then
            echo "=== Submodule empty, cloning ReSukiSU directly ==="
            rm -rf KernelSU
            git clone --depth=1 https://github.com/ReSukiSU/ReSukiSU.git KernelSU
        fi
        if [ ! -L drivers/kernelsu ]; then
            ln -sf ../KernelSU/kernel drivers/kernelsu
        fi
        grep -q "kernelsu" drivers/Makefile || \
            printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> drivers/Makefile
        echo "=== ReSukiSU ready ==="
        cd $KERNEL
    fi
}

setup_ntsync() {
    echo "=== Applying ntsync (NT synchronization primitives) ==="
    cd $KERNEL_SOURCE

    # Copy ntsync driver source
    cp $KERNEL/patches/ntsync/ntsync.c drivers/misc/
    echo "  -> drivers/misc/ntsync.c copied"

    # Copy UAPI header
    cp $KERNEL/patches/ntsync/ntsync.h include/uapi/linux/
    echo "  -> include/uapi/linux/ntsync.h copied"

    # Add entry to drivers/misc/Makefile
    grep -q "CONFIG_NTSYNC" drivers/misc/Makefile || \
        printf "obj-\$(CONFIG_NTSYNC)\t\t+= ntsync.o\n" >> drivers/misc/Makefile
    echo "  -> drivers/misc/Makefile patched"

    # Add Kconfig entry (before endmenu)
    grep -q "config NTSYNC" drivers/misc/Kconfig || \
        sed -i "/endmenu/i\config NTSYNC\n\ttristate \"NT synchronization primitive emulation\"\n\tdefault y\n\thelp\n\t  This module provides kernel support for emulation of Windows NT\n\t  synchronization primitives for Wine/Proton. It is not a hardware driver.\n\t  If unsure, say N.\n" drivers/misc/Kconfig
    echo "  -> drivers/misc/Kconfig patched"

    echo "=== ntsync ready ==="
    cd $KERNEL
}

clone_anykernel() {
    echo "=== Setting up AnyKernel ==="
    if [ ! -d $ANYKERNEL_DIR ]; then
        git clone --depth=1 $ANYKERNEL_LINK $ANYKERNEL_DIR
    fi
    echo "=== Patching AnyKernel for 6GB ZRAM & Overlay ==="
    # 1. Inject overlay.d/init.zram.rc into AnyKernel ramdisk for automatic post-boot 6GB ZRAM enforcement
    mkdir -p $ANYKERNEL_DIR/ramdisk/overlay.d
    cat << 'EOF' > $ANYKERNEL_DIR/ramdisk/overlay.d/init.zram.rc
on property:sys.boot_completed=1
    exec - root root -- /system/bin/sh -c "swapoff /dev/block/zram0 2>/dev/null; echo 1 > /sys/block/zram0/reset 2>/dev/null; echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null; echo 6442450944 > /sys/block/zram0/disksize 2>/dev/null; mkswap /dev/block/zram0 2>/dev/null; swapon /dev/block/zram0 -p 32767 2>/dev/null"
EOF

    # 2. Patch anykernel.sh for fstab modification during flashing
    if [ -f $ANYKERNEL_DIR/anykernel.sh ]; then
        grep -q "Patching ZRAM size to 6GB" $ANYKERNEL_DIR/anykernel.sh || \
            sed -i '/dump_boot;/a \
ui_print "Patching ZRAM size to 6GB (6442450944 bytes)...";\
for fstab in $ramdisk/fstab* $ramdisk/etc/fstab* $ramdisk/vendor/etc/fstab* /vendor/etc/fstab* /system/etc/fstab*; do\
  if [ -f "$fstab" ] && grep -q "zram" "$fstab"; then\
    sed -i -E "s/zramsize=[0-9%]+/zramsize=6442450944/g" "$fstab" 2>/dev/null || true;\
  fi;\
done;' $ANYKERNEL_DIR/anykernel.sh
    fi
}

build() {
    START=$(date +%s)

    cd $KERNEL_SOURCE

    export ARCH=arm64
    export SUBARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
    export CC="ccache clang"
    export HOSTCC=gcc
    export LD=ld.lld
    export AS=llvm-as
    export AR=llvm-ar
    export NM=llvm-nm
    export OBJCOPY=llvm-objcopy
    export OBJDUMP=llvm-objdump
    export STRIP=llvm-strip
    export LLVM=1
    export LLVM_IAS=1
    export KBUILD_BUILD_USER=DroidSpace
    export KBUILD_BUILD_HOST=github-actions

    OUT=out

    echo "=== Copying DroidSpaces config ==="
    mkdir -p arch/arm64/configs/vendor/xiaomi
    cp $KERNEL/configs/droidspaces.config arch/arm64/configs/vendor/xiaomi/droidspaces.config

    echo "=== Configuring kernel ==="
    make O="$OUT" vendor/alioth_defconfig 2>&1 | tee ../build_config.log || make O="$OUT" alioth_defconfig 2>&1 | tee ../build_config.log
    # Merge config fragments properly
    scripts/kconfig/merge_config.sh -O "$OUT" \
        "$OUT/.config" \
        arch/arm64/configs/vendor/xiaomi/droidspaces.config 2>&1 | tee -a ../build_config.log
    make O="$OUT" olddefconfig 2>&1 | tee -a ../build_config.log
    # Verify KSU is enabled
    grep -q "CONFIG_KSU=y" "$OUT/.config" && echo "KSU enabled: YES" || echo "WARNING: KSU not enabled!"
    # Verify ntsync is enabled
    grep -q "CONFIG_NTSYNC=y" "$OUT/.config" && echo "ntsync enabled: YES" || echo "WARNING: ntsync not enabled!"
    # Verify cgroup v2 is enabled
    grep -q "CONFIG_CGROUP2=y" "$OUT/.config" && echo "cgroup v2: YES" || echo "WARNING: cgroup v2 not enabled!"
    # Verify SUSFS is enabled
    grep -q "CONFIG_KSU_SUSFS=y" "$OUT/.config" && echo "SUSFS enabled: YES" || echo "WARNING: SUSFS not enabled!"
    # Verify MGLRU is enabled
    grep -q "CONFIG_LRU_GEN=y" "$OUT/.config" && echo "MGLRU enabled: YES" || echo "WARNING: MGLRU not enabled!"
    # Verify 1000Hz timer tick is enabled
    grep -q "CONFIG_HZ_1000=y" "$OUT/.config" && echo "1000Hz Timer Tick: YES" || echo "WARNING: 1000Hz not enabled!"
    # Verify ZSTD ZRAM is enabled
    grep -q "CONFIG_ZRAM_DEF_COMP_ZSTD=y" "$OUT/.config" && echo "ZSTD ZRAM: YES" || echo "WARNING: ZSTD ZRAM not enabled!"

    # Set kernel local version suffix — kernel reports "DroidSpace" in `uname -r`
    LOCALVERSION="-DroidSpace"
    scripts/config --file "$OUT/.config" --set-str CONFIG_LOCALVERSION "$LOCALVERSION"
    if grep -q '^CONFIG_LOCALVERSION="-DroidSpace"$' "$OUT/.config"; then
        echo "Local version: DroidSpace"
    else
        echo "WARNING: Local version not set correctly!"
        grep "CONFIG_LOCALVERSION" "$OUT/.config" || true
    fi

    echo "=== Building kernel ==="
    make -j$(nproc) \
        O="$OUT" \
        CC="ccache clang" \
        HOSTCC=gcc \
        LD=ld.lld \
        AS=llvm-as \
        AR=llvm-ar \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        LLVM=1 \
        LLVM_IAS=1 \
        KBUILD_BUILD_USER="DroidSpace" \
        KBUILD_BUILD_HOST="github-actions" \
        2>&1 | tee ../build.log

    END=$(date +%s)
    ELAPSED=$((END - START))

    if grep -q -E "Error 2|error:" build.log; then
        echo "ERROR: Build failed!"
        exit 1
    fi

    echo "Build completed in $ELAPSED seconds"
}

package() {
    echo "=== Packaging kernel ==="

    cd $KERNEL_SOURCE

    DTS=arch/arm64/boot/dts/vendor
    IMG=$ANYKERNEL_DIR/Image
    DTB=$ANYKERNEL_DIR/dtb
    DTBO=$ANYKERNEL_DIR/dtbo.img

    find $DTS -name '*.dtb' -exec cat {} + > $DTB
    find $DTS -name 'Image' -exec cat {} + > $IMG

    if [ -f $DTS/xiaomi/${DEVICE}/dtbo.img ]; then
        cp $DTS/xiaomi/${DEVICE}/dtbo.img $DTBO
    fi

    cd $ANYKERNEL_DIR

    BUILD_DATE=$(date '+%Y-%m-%d_%H-%M-%S')

    rm -f *.zip
    7z a -mx9 Droidspace-${DEVICE}-v${VERSION}.zip * -x!*.zip

    cp Droidspace-${DEVICE}-v${VERSION}.zip $KERNEL/

    echo "Package created: Droidspace-${DEVICE}-v${VERSION}.zip"
}

setup_toolchains
clone_kernel
setup_ntsync
clone_anykernel
build
package
