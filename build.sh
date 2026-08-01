#!/bin/bash

source settings.sh

#
# Droidspace Kernel build script
# Adapted from TIMISONG-dev/MagicTime kernel build.sh
#

KERNEL=$PWD
KERNEL_SOURCE=$KERNEL/kernel_source

CLANG=$KERNEL/toolchains/clang
KERNEL_REPO="https://github.com/TIMISONG-dev/kernel_xiaomi_sm8250.git"
KERNEL_BRANCH="magictime-new"
ANYKERNEL_LINK="https://github.com/TIMISONG-dev/MagicTime-alioth"
ANYKERNEL_DIR=$KERNEL/AnyKernel

setup_toolchains() {
    echo "=== Setting up toolchains ==="

    if [ ! -d $CLANG ]; then
        echo "Downloading Clang..."
        mkdir -p $CLANG
        wget -q -O /tmp/clang.tar.gz "https://github.com/ZyCromerZ/Clang/releases/download/20.0.0git-20250129-release/Clang-20.0.0git-20250129.tar.gz"
        tar -zxf /tmp/clang.tar.gz -C $CLANG
        rm -f /tmp/clang.tar.gz
    fi

    export PATH=$CLANG/bin:$PATH
}

clone_kernel() {
    echo "=== Cloning kernel source (${KERNEL_REPO} - branch: ${KERNEL_BRANCH}) ==="
    if [ ! -d $KERNEL_SOURCE ]; then
        git clone --depth=1 -b $KERNEL_BRANCH $KERNEL_REPO $KERNEL_SOURCE
        cd $KERNEL_SOURCE
        rm -rf KernelSU-Next
        git config --unset-all submodule.KernelSU-Next.url 2>/dev/null || true
        echo "=== Cloning rsuntk/KernelSU (main) ==="
        git clone --depth=1 \
            https://github.com/rsuntk/KernelSU.git \
            KernelSU-Next
        if [ ! -L drivers/kernelsu ]; then
            ln -sf ../KernelSU-Next/kernel drivers/kernelsu
        fi
        grep -q "kernelsu" drivers/Makefile || \
            printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> drivers/Makefile
        grep -q "drivers/kernelsu/Kconfig" drivers/Kconfig || \
            sed -i "/endmenu/i\source \"drivers/kernelsu/Kconfig\"" drivers/Kconfig
        sed -i 's/&current->cpus_allowed);/\&current->cpus_mask);/g' \
            KernelSU-Next/kernel/selinux/rules.c 2>/dev/null || true
        echo "=== rsuntk/KernelSU ready ==="
        cd $KERNEL
    fi
}

setup_susfs() {
    echo "=== Setting up SUSFS anti-detection ==="
    if [ ! -d $KERNEL/toolchains/susfs4ksu ]; then
        git clone --depth=1 -b kernel-4.19 https://gitlab.com/simonpunk/susfs4ksu.git $KERNEL/toolchains/susfs4ksu 2>/dev/null || \
            git clone --depth=1 https://github.com/sidex15/susfs4ksu.git $KERNEL/toolchains/susfs4ksu 2>/dev/null || true
    fi
    if [ -d "$KERNEL/toolchains/susfs4ksu/kernel_patches" ]; then
        echo "=== Copying SUSFS files into kernel source ==="
        cp -r $KERNEL/toolchains/susfs4ksu/kernel_patches/include/linux/susfs*.h $KERNEL_SOURCE/include/linux/ 2>/dev/null || true
        cp $KERNEL/toolchains/susfs4ksu/kernel_patches/fs/susfs.c $KERNEL_SOURCE/fs/ 2>/dev/null || true
        cd $KERNEL_SOURCE
        echo "=== Patching Linux 4.19 VFS for SUSFS ==="
        patch -p1 < $KERNEL/toolchains/susfs4ksu/kernel_patches/50_add_susfs_in_kernel-4.19.patch 2>/dev/null || true
        if [ -f $KERNEL/toolchains/susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ]; then
            patch -p1 -d drivers/kernelsu < $KERNEL/toolchains/susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch 2>/dev/null || true
        fi
        echo "=== SUSFS patched successfully ==="
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
    printf 'on property:sys.boot_completed=1\n    exec - root root -- /system/bin/sh -c "if [ $(cat /sys/block/zram0/disksize 2>/dev/null || echo 0) -lt 6442450944 ]; then swapoff /dev/block/zram0 2>/dev/null; echo 1 > /sys/block/zram0/reset 2>/dev/null; echo 6442450944 > /sys/block/zram0/disksize 2>/dev/null; mkswap /dev/block/zram0 2>/dev/null; swapon /dev/block/zram0 -p 32767 2>/dev/null; fi"\n' > $ANYKERNEL_DIR/ramdisk/overlay.d/init.zram.rc

    # 2. Add dynamic fstab patch in anykernel.sh
    if [ -f $ANYKERNEL_DIR/anykernel.sh ]; then
        grep -q "Patching ZRAM size to 6GB" $ANYKERNEL_DIR/anykernel.sh || \
            printf '\n# Patch fstab for 6GB ZRAM\nui_print "Patching ZRAM size to 6GB (6442450944 bytes)...";\nfor fstab in $ramdisk/fstab* $ramdisk/etc/fstab* $ramdisk/vendor/etc/fstab* /vendor/etc/fstab* /system/etc/fstab*; do\n  if [ -f "$fstab" ] && grep -q "zram" "$fstab"; then\n    sed -i -E "s/zramsize=[0-9%%]+/zramsize=6442450944/g" "$fstab" 2>/dev/null || true;\n  fi;\ndone;\n' >> $ANYKERNEL_DIR/anykernel.sh
    fi
}

build() {
    START=$(date +%s)

    cd $KERNEL_SOURCE

    export ARCH=arm64
    export SUBARCH=arm64
    export PATH=$CLANG/bin:$PATH
    export KBUILD_BUILD_USER=DroidSpace
    export KBUILD_BUILD_HOST=github-actions

    OUT=out

    echo "=== Copying DroidSpaces config ==="
    mkdir -p arch/arm64/configs/vendor/xiaomi
    cp $KERNEL/configs/droidspaces.config arch/arm64/configs/vendor/xiaomi/droidspaces.config

    echo "=== Configuring kernel ==="
    make O="$OUT" ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 vendor/alioth_defconfig 2>&1 | tee ../build_config.log || make O="$OUT" ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 alioth_defconfig 2>&1 | tee ../build_config.log
    # Merge config fragments properly
    scripts/kconfig/merge_config.sh -O "$OUT" \
        "$OUT/.config" \
        arch/arm64/configs/vendor/xiaomi/droidspaces.config 2>&1 | tee -a ../build_config.log
    make O="$OUT" ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 olddefconfig 2>&1 | tee -a ../build_config.log
    # Verify KSU is enabled
    grep -q "CONFIG_KSU=y" "$OUT/.config" && echo "KSU enabled: YES" || echo "WARNING: KSU not enabled!"
    # Verify ntsync is enabled
    grep -q "CONFIG_NTSYNC=y" "$OUT/.config" && echo "ntsync enabled: YES" || echo "WARNING: ntsync not enabled!"
    # Verify cgroup v2 is enabled
    grep -q "CONFIG_CGROUP2=y" "$OUT/.config" && echo "cgroup v2: YES" || echo "WARNING: cgroup v2 not enabled!"
    # Verify 1000Hz timer tick is enabled
    grep -q "CONFIG_HZ_1000=y" "$OUT/.config" && echo "1000Hz Timer Tick: YES" || echo "WARNING: 1000Hz not enabled!"
    # Verify ZSTD ZRAM is enabled
    grep -q "CONFIG_ZRAM_DEF_COMP_ZSTD=y" "$OUT/.config" && echo "ZSTD ZRAM: YES" || echo "WARNING: ZSTD ZRAM not enabled!"

    # Set kernel local version suffix — kernel reports "DroidSpace" in `uname -r`
    LOCALVERSION="-DroidSpace"
    scripts/config --file "$OUT/.config" --set-str CONFIG_LOCALVERSION "$LOCALVERSION"

    echo "=== Building kernel ==="
    make -j$(nproc) \
        O="$OUT" \
        ARCH=arm64 \
        SUBARCH=arm64 \
        CC=clang \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
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
setup_susfs
setup_ntsync
clone_anykernel
build
package
