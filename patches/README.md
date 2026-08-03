# Kernel patches

Cada subdiretório de `patches/` contém uma série de patches a serem aplicados
sobre a árvore do kernel MagicTime (`TIMISONG-dev/kernel_xiaomi_sm8250`,
branch `magictime-tiny`), em ordem alfabética (ex.: `0001-...`, `0002-...`).

O workflow de build aplica **todos** os `patches/*/*.patch` em ordem com:

```sh
for patch in patches/*/*.patch; do
  git apply --verbose "$patch"
done
```

## Diretórios

- `ntsync/` — driver ntsync (Wine/Proton), diretamente do upstream.
- `mglru/` — backport do Multi-Gen LRU para o kernel 4.19.
- `io_uring/` — backport do io_uring v5.1 para o kernel 4.19.

## io_uring/

Backport do io_uring (mainline **v5.1**) para o kernel 4.19. O v5.1 é
autocontido (`fs/io_uring.c` + `include/uapi/linux/io_uring.h`), sem a
dependência de io-wq (que só chega no 5.2).

O patch `0001-io_uring-5.1-backport.patch` é a consolidação do port (17
arquivos, +3438/-11) sobre a base `e764f7231` do `magictime-tiny` e inclui as
adaptações para o 4.19:

- `kernel/signal.c`/`include/linux/signal.h`/`include/linux/compat.h`:
  helpers de sigmask do v5.1 (`set_user_sigmask`,
  `set_compat_user_sigmask`, `restore_user_sigmask`)
- `include/linux/ioprio.h`: `get_current_ioprio()`
- `include/linux/uio.h`: `ITER_BVEC_FLAG_NO_REF` + `iov_iter_bvec_no_ref()`
- `include/linux/bvec.h`: `bvec_nth_page()`/`mp_bvec_for_each_page()`
  (macros)
- `include/linux/blk_types.h` + `block/bio.c`: `BIO_NO_PAGE_REF` e
  `__bio_iov_bvec_add_pages()`
- `include/linux/fs.h`: `f_op->iopoll`, `io_uring_get_socket()`;
  `net/unix/scm.c`: chamada em `unix_get_socket()`
- Syscalls 425/426/427 (`unistd.h`, `syscalls.h`, `sys_ni.c`), `init/Kconfig`
  (`config IO_URING`), `fs/Makefile`

Habilite com a config fragment em `configs/droidspaces.config`:

```
CONFIG_IO_URING=y
```

Referência da árvore final aplicada: worktree local
`io_uring-wt` (base `e764f7231`, branch `io_uring-5.1-backport`).

## mglru/

Backport do MGLRU (série FROMLIST do Google, "Bug: 228114874") para o kernel
4.19, feito a partir da cadeia de commits
`53da10c..28c7e93ce04cbe1dfabe3a02a149a7b3c09ae1ad` do kernel
`AlcatrazDev-Android-Devices/kernel_lge_sm8250` (mesma base CAF 4.19 qcom
sm8250). São 29 commits: refactors de LRU API + suporte a
`arch_has_hw_pte_young` + os 10 FROMLIST do MGLRU + fixes específicos da
qualcomm.

O patch `0001-mglru.patch` é a consolidação final (45 arquivos, ~4300 linhas)
e já contém as resoluções manuais necessárias para a base do MagicTime:

- `fs/fuse/dev.c`: `LRU_GEN_MASK | LRU_REFS_MASK` em `fuse_check_page()`
- `mm/swapfile.c` (`unuse_mm`): `activate_page()` condicionado a
  `!lru_gen_enabled()` mantendo o `mmap_read_trylock`/`mmap_read_lock`
- `mm/workingset.c`: mantida a variante `EVICTION_MASK`/xarray do Xiaomi
  (removido `eviction >>= bucket_order` de `pack_shadow()`)
- `include/linux/cgroup.h`: stubs `cgroup_lock()`/`cgroup_unlock()` na seção
  `#else /* !CONFIG_CGROUPS */`
- `arch/arm64/include/asm/pgtable.h`: define
  `arch_has_hw_pte_young cpu_has_hw_af` (cpufeature do arm64)
- `mm/swap.c`: `SetPageActive()` condicionado a `!lru_gen_enabled()` em
  `lru_cache_add_active_or_unevictable()`

O commit `833e95e` (tweak Motorola de `get_nr_to_scan`) foi propositalmente
deixado de fora — o MagicTime já usa a variante AOSP/upstream.

Habilite com as configs fragment em `configs/droidspaces.config`:

```
CONFIG_LRU_GEN=y
CONFIG_LRU_GEN_ENABLED=y
```

Referência da árvore final aplicada: worktree local
`timisong-mglru` (base `e764f7231`, 45 arquivos, +4326/-397).
