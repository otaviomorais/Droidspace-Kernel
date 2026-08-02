#!/bin/bash
# ReSukiSU Manual Hook Patcher for Linux 4.19
# Applies mandatory ksu_handle_* hooks to kernel source files
# Usage: ./apply_hooks.sh <kernel_source_dir>

KSRC="${1:-$PWD}"

if [ ! -d "$KSRC/fs" ]; then
    echo "ERROR: Kernel source directory not found at $KSRC"
    exit 1
fi

echo "=== Applying ReSukiSU manual hooks to kernel 4.19 ==="

# 1. fs/exec.c - ksu_handle_execveat hook
#    Insert before the first 'return' in do_execveat_common or __do_execve_file
#    Target: __do_execve_file() or do_execveat_common()
EXEC_HOOK_FILE="$KSRC/fs/exec.c"
echo "[1/5] Patching fs/exec.c for ksu_handle_execveat..."

# Find __do_execve_file function or do_execveat_common
if grep -q "__do_execve_file" "$EXEC_HOOK_FILE"; then
    EXEC_FUNC="__do_execve_file"
elif grep -q "do_execveat_common" "$EXEC_HOOK_FILE"; then
    EXEC_FUNC="do_execveat_common"
else
    echo "  WARNING: Could not find execeve function in $EXEC_HOOK_FILE"
fi

# Add extern declaration before the function
if ! grep -q "ksu_handle_execveat" "$EXEC_HOOK_FILE"; then
    # Add at top of file (after last #include)
    LINE=$(grep -n "^#include" "$EXEC_HOOK_FILE" | tail -1 | cut -d: -f1)
    sed -i "${LINE}a\\
\\
#ifdef CONFIG_KSU\\
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv, void *envp, int *flags);\\
#endif" "$EXEC_HOOK_FILE"
    echo "  -> extern declaration added"
fi

# Insert ksu_handle_execveat call in the function
# Strategy: find the beginning of the function and insert after variable declarations
EXEC_LINE=$(grep -n "$EXEC_FUNC" "$EXEC_HOOK_FILE" | head -1 | cut -d: -f1)
if [ -n "$EXEC_LINE" ]; then
    # Find the point after local variable declarations (find the first line that isn't a var decl or comment)
    # Insert after first "int"/"char" etc declarations block
    INSERT_LINE=$((EXEC_LINE + 10))
    # Check if already patched
    if ! grep -A 50 "$EXEC_FUNC" "$EXEC_HOOK_FILE" | grep -q "ksu_handle_execveat"; then
        sed -i "${INSERT_LINE}i\\
#ifdef CONFIG_KSU\\
\tif (unlikely(ksu_su_compat_enabled)) {\\
\t\tksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);\\
\t}\\
#endif" "$EXEC_HOOK_FILE"
        echo "  -> ksu_handle_execveat call added"
    else
        echo "  -> Already patched"
    fi
fi

# 2. fs/open.c - ksu_handle_faccessat hook
echo "[2/5] Patching fs/open.c for ksu_handle_faccessat..."
OPEN_FILE="$KSRC/fs/open.c"
FACCESSAT_LINE=$(grep -n "SYSCALL_DEFINE4.faccessat\|SYSCALL_DEFINE3.faccessat" "$OPEN_FILE" | head -1 | cut -d: -f1)

if [ -n "$FACCESSAT_LINE" ] && ! grep -q "ksu_handle_faccessat" "$OPEN_FILE"; then
    # Add extern declaration if needed
    if ! grep -q "ksu_handle_faccessat" "$OPEN_FILE"; then
        sed -i "${FACCESSAT_LINE}i\\
#ifdef CONFIG_KSU\\
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode, int *__unused_flags);\\
#endif" "$OPEN_FILE"
        FACCESSAT_LINE=$((FACCESSAT_LINE + 3))  # adjust for inserted lines
    fi
    # Find the return statement in faccessat and insert before it
    FAC_RET_LINE=$(grep -n "return do_faccessat\|return faccessat" "$OPEN_FILE" | head -1 | cut -d: -f1)
    if [ -n "$FAC_RET_LINE" ]; then
        sed -i "${FAC_RET_LINE}i\\
#ifdef CONFIG_KSU\\
\t{\\
\t\tint ksu_df = dfd;\\
\t\tint ksu_mode = mode;\\
\t\tksu_handle_faccessat(&ksu_df, &filename, &ksu_mode, NULL);\\
\t}\\
#endif" "$OPEN_FILE"
        echo "  -> ksu_handle_faccessat hook added"
    fi
else
    echo "  -> Already patched or not found"
fi

# 3. fs/stat.c - ksu_handle_stat, ksu_handle_newfstat_ret, ksu_handle_fstat64_ret
echo "[3/5] Patching fs/stat.c..."
STAT_FILE="$KSRC/fs/stat.c"

if ! grep -q "ksu_handle_stat" "$STAT_FILE"; then
    # Add externs at top
    LINE=$(grep -n "^#include" "$STAT_FILE" | tail -1 | cut -d: -f1)
    sed -i "${LINE}a\\
\\
#ifdef CONFIG_KSU\\
extern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\\
extern void ksu_handle_newfstat_ret(unsigned int *fd, struct stat __user **statbuf_ptr);\\
extern void ksu_handle_fstate64_ret(unsigned long *fd, struct stat64 __user **statbuf_ptr);\\
#endif" "$STAT_FILE"

    # Add ksu_handle_newfstat_ret to sys_newstat
    NEWSTAT_LINE=$(grep -n "SYSCALL_DEFINE2.newfstat\|SYSCALL_DEFINE2.newstat" "$STAT_FILE" | head -1 | cut -d: -f1)
    if [ -n "$NEWSTAT_LINE " ]; then
        # Insert after function opening brace
        BRACE_LINE=$((NEWSTAT_LINE + 1))
        sed -i "${BRACE_LINE}i\\
\t#ifdef CONFIG_KSU\\
\tksu_handle_newfstat_ret(&fd, &statbuf);\\
\t#endif" "$STAT_FILE"
        echo "  -> ksu_handle_newfstat_ret added"
    fi

    # Add ksu_handle_fstat64_ret
    FSTAT64_LINE=$(grep -n "SYSCALL_DEFINE2.fstat64" "$STAT_FILE" | head -1 | cut -d: -f1)
    if [ -n "$FSTAT64_LINE" ]; then
        BRACE_LINE=$((FSTAT64_LINE + 1))
        sed -i "${BRACE_LINE}i\\
\t#ifdef CONFIG_KSU\\
\tksu_handle_fstat64_ret(&fd, &statbuf);\\
\t#endif" "$STAT_FILE"
        echo "  -> ksu_handle_fstat64_ret added"
    fi

    # Add ksu_handle_stat to newfstatat
    NEWFSTATAT_LINE=$(grep -n "SYSCALL_DEFINE4.newfstatat\|SYSCALL_DEFINE4.fstatat64\|SYSCALL_DEFINE2.newfstatat" "$STAT_FILE" | head -1 | cut -d: -f1)
    if [ -n "$NEWFSTATAT_LINE" ]; then
        BRACE_LINE=$((NEWFSTATAT_LINE + 1))
        sed -i "${BRACE_LINE}i\\
\t#ifdef CONFIG_KSU\\
\tksu_handle_fstatat(&ksu_df, &filename, &flag);\\
\t#endif" "$STAT_FILE"
        echo "  -> ksu_handle_stat added"
    fi
else
    echo "  -> Already patched"
fi

# 4. kernel/reboot.c - ksu_handle_sys_reboot
echo "[4/5] Patching kernel/reboot.c..."
REBOOT_FILE="$KSRC/kernel/reboot.c"

if ! grep -q "ksu_handle_sys_reboot" "$EBOOT_FILE"; then
    REBOOT_LINE=$(grep -n "SYSCALL_DEFINE4.reboot" "$REBOOT_FILE" | head -1 | cut -d: -f1)
    if [ -n "$REBOOT_LINE" ]; then
        # Insert after first return statement that checks magic
        sed -i "${REBOOT_LINE}i\\
#ifdef CONFIG_KSU\\
extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);\\
#endif" "$REBOOT_FILE"
        REBOOT_LINE=$((REBOOT_LINE + 3))

        # Insert the hook at the beginning of the function (after local vars)
        BRACE_LINE=$((REBOOT_LINE + 3))
        sed -i "${BRACE_LINE}i\\
#ifdef CONFIG_KSU\\
\tksu_handle_sys_reboot(magic1, magic2, cmd, &arg);\\
#endif" "$REBOOT_FILE"
        echo "  -> ksu_handle_sys_reboot added"
    fi
else
    echo "  -> Already patched"
fi

# 5. SUSFS kernel integration - copy susfs files and patch
echo "[5/5] Integrating SUSFS into kernel tree..."
SUSFS_SRC="$KSRC/../../susks4ksu/kernel_patches"

# Copy SUSFS files to kernel if patched
if [ -f "$SUSFS_SRC/fs/susfs.c" ]; then
    cp "$SUSFS_SRC/fs/susfs.c" "$KSRC/fs/"
    cp -r "$SUSFS_SRC/include/linux/susfs"* "$KSRC/include/linux/" 2>/dev/null || true
    echo "  -> SUSFS files added"
fi

echo ""
echo "=== ReSukiSU manual hooks applied ==="
echo "Verify with: git diff fs/ kernel/"