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
KERNEL_REPO="https://github.com/TIMISONG-dev/kernel_xiaomi_sm8250.git"
KERNEL_BRANCH="magictime-new"
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
    echo "=== Cloning kernel source ==="
    if [ ! -d $KERNEL_SOURCE ]; then
        git clone --depth=1 -b $KERNEL_BRANCH $KERNEL_REPO $KERNEL_SOURCE
        cd $KERNEL_SOURCE
        # Remove stale KernelSU-Next submodule (commit fc33995 doesn't exist upstream)
        rm -rf KernelSU-Next
        git config --unset-all submodule.KernelSU-Next.url 2>/dev/null || true
        # Clone KernelSU-Next v3.2.0-legacy (v3.3.0 requer APIs 5.10+; SM8250 é 4.19)
        echo "=== Cloning KernelSU-Next v3.2.0-legacy ==="
        git clone --depth=1 --branch v3.2.0-legacy \
            https://github.com/KernelSU-Next/KernelSU-Next.git \
            KernelSU-Next
        if [ ! -f KernelSU-Next/kernel/Kbuild ]; then
            echo "ERROR: KernelSU-Next failed to checkout!"
            exit 1
        fi
        # Ensure symlink exists (upstream has it, but verify)
        if [ ! -L drivers/kernelsu ]; then
            ln -sf ../KernelSU-Next/kernel drivers/kernelsu
        fi
        # Ensure Makefile entry exists
        grep -q "kernelsu" drivers/Makefile || \
            printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> drivers/Makefile
        # Ensure Kconfig entry exists
        grep -q "drivers/kernelsu/Kconfig" drivers/Kconfig || \
            sed -i "/endmenu/i\source \"drivers/kernelsu/Kconfig\"" drivers/Kconfig
        # Patch for kernel 4.19: cpus_allowed renamed to cpus_mask
        echo "=== Patching KernelSU-Next for kernel 4.19 compat ==="
        sed -i 's/&current->cpus_allowed);/\&current->cpus_mask);/g' \
            KernelSU-Next/kernel/selinux/rules.c
        echo "=== KernelSU-Next v3.2.0-legacy ready ==="
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
    export KBUILD_BUILD_USER=Droidspace
    export KBUILD_BUILD_HOST=github-actions

    OUT=out

    echo "=== Copying DroidSpaces config ==="
    mkdir -p arch/arm64/configs/vendor/xiaomi
    cp $KERNEL/configs/droidspaces.config arch/arm64/configs/vendor/xiaomi/droidspaces.config

    echo "=== Configuring kernel ==="
    make O="$OUT" ${DEVICE}_defconfig 2>&1 | tee ../build_config.log
    # Merge config fragments properly
    scripts/kconfig/merge_config.sh -O "$OUT" \
        "$OUT/.config" \
        arch/arm64/configs/vendor/xiaomi/magictime-common.config \
        arch/arm64/configs/vendor/xiaomi/droidspaces.config 2>&1 | tee -a ../build_config.log
    make O="$OUT" olddefconfig 2>&1 | tee -a ../build_config.log
    # Verify KSU is enabled
    grep -q "CONFIG_KSU=y" "$OUT/.config" && echo "KSU enabled: YES" || echo "WARNING: KSU not enabled!"
    # Verify ntsync is enabled
    grep -q "CONFIG_NTSYNC=y" "$OUT/.config" && echo "ntsync enabled: YES" || echo "WARNING: ntsync not enabled!"

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
