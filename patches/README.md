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
