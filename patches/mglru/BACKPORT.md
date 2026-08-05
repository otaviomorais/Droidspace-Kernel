# Backport do Multi-Gen LRU (MGLRU) para a base do Pulsar (staging-bpf)

Registro do backport do MGLRU para a base do Pulsar
(branch `staging-bpf`, kernel 4.19.404) e da
entrega como `patches/mglru/0001-mglru.patch` no repo
`Pulsar-Kernel`.

## 1. Contexto

O usuário migrou do kernel MagicTime (base timisong `e764f7231`, onde o MGLRU
já rodava via `patches/mglru/0001-mglru.patch`) para a nova base (`staging-bpf`),
que tem swap cache em **xarray** e pagewalk **ops-based**. O patch original foi
testado na base timisong; 13 de 47 arquivos falharam no `git apply --reject` no
na nova base, sem conflito conceitual — só contexto divergente.

Diferenças relevantes da nova base vs timisong:
- `mmap_sem` (não `mmap_lock`).
- `__delete_from_swap_cache(page, entry)` com xarray (não `(page)` com
  radix-tree).
- Sem `gfp_compaction_allowed`; usa `IS_ENABLED(CONFIG_COMPACTION)`.
- Pagewalk ops-based: `struct mm_walk_ops` em `include/linux/pagewalk.h`
  (não `struct mm_walk` em `include/linux/mm.h`); assinatura
  `walk_page_range(mm, start, end, ops, private)`.

## 2. Resoluções manuais dos rejects

| Arquivo | Resolução |
|---|---|
| `arch/arm64/include/asm/pgtable.h` | +`#define arch_has_hw_pte_young cpu_has_hw_af` após `<asm-generic/pgtable.h>` |
| `include/linux/mm_types.h` | +`#include <linux/nodemask.h>` e `#include <linux/mmdebug.h>` antes do `android_kabi.h` |
| `fs/fuse/dev.c` | `LRU_GEN_MASK \| LRU_REFS_MASK` em `fuse_check_page()` |
| `kernel/sched/core.c` | +`lru_gen_use_mm(next->mm)` após `switch_mm_irqs_off` (branch "to user") |
| `mm/swapfile.c` | `if (!lru_gen_enabled()) activate_page(page)` em `unuse_pte`/`unuse_mm` |
| `mm/Kconfig` | bloco `# multi-gen LRU {` (LRU_GEN, LRU_GEN_ENABLED, LRU_GEN_STATS) antes de `endmenu` |
| `include/linux/pagewalk.h` + `mm/pagewalk.c` | `p4d_entry` adicionado ao `struct mm_walk_ops`; `walk_p4d_range` chama `ops->p4d_entry`; `walk_pgd_range` estende condição p/ `ops->p4d_entry` |
| `mm/vmscan.c` (`__remove_mapping`) | `shadow = lru_gen_eviction(page)` no branch `PageSwapCache` + `__delete_from_swap_cache(page, swap, shadow)` |
| `mm/vmscan.c` (bloco MGLRU) | `gfp_compaction_allowed` → `IS_ENABLED(CONFIG_COMPACTION)`; `mmap_lock` → `mmap_sem`; `walk_mm()` adaptado para ops (`mm_walk_ops` com `.test_walk`/`.p4d_entry`) |
| `mm/swap_state.c` + `include/linux/swap.h` | adaptação xarray (ver seção 3) |
| `mm/swap.c` | `lru_deactivate_fn` convertido para a API 2-arg (`del/add_page_to_lru_list(page, lruvec)`) |

**Pulados** (desnecessários na nova base — swap cache é xarray, não radix-tree):
- `lib/radix-tree.c` (export `__radix_tree_create`)
- `include/linux/radix-tree.h` (protótipo)

## 3. Adaptação xarray do swap cache (shadow entries)

A nova base já usa `xa_store`/`XA_STATE` em `add_to_swap_cache`/`__delete_from_swap_cache`
(estrutura do commit upstream `3852f6768ede` "mm/swapcache: support to handle
the shadow entries"), então a série do patch original (que esperava
`__add_to_swap_cache(page, entry, shadowp)` via radix-tree) foi reaplicada no
padrão xarray:

- `add_to_swap_cache(page, entry, gfp, void **shadowp)` — lê `old = xas_load()`;
  se `xa_is_value(old)` grava `*shadowp` e decrementa `address_space->nrexceptional`.
- `__delete_from_swap_cache(page, entry, void *shadow)` — `xas_store(&xas, shadow)`
  em vez de `NULL`.
- `clear_shadow_from_swap_cache(type, begin, end)` — varre os swapper_spaces com
  `xas_for_each`/`xas_store(NULL)` (versão xarray do mainline 6.1).
- `__read_swap_cache_async` — passa `&shadow` ao `add_to_swap_cache`; no sucesso:
  `if (!lru_gen_enabled()) SetPageWorkingset(new_page); else if (shadow)
  lru_gen_refault(new_page, shadow);`.
- `__remove_mapping` (vmscan.c) — `if (lru_gen_enabled()) shadow =
  lru_gen_eviction(page)` antes de `mem_cgroup_swapout`; `__delete_from_swap_cache
  (page, swap, shadow)`.
- `shmem.c` — `add_to_swap_cache(page, swap, GFP_ATOMIC, NULL)`.

## 4. Verificações

- `git apply --check --reverse` do patch sobre a árvore modificada passa limpo
  (≡ aplica forward em checkout fresco).
- Build local completo (Clang 18, `vendor/alioth_defconfig` + fragment
  `droidspace.config` com `CONFIG_LRU_GEN=y`/`CONFIG_LRU_GEN_ENABLED=y`):
  `Image`/`vmlinux` gerados sem erro.
- Símbolos MGLRU presentes no vmlinux: `lru_gen_eviction`, `lru_gen_refault`,
  `lru_gen_look_around`, `walk_mm.mm_walk_ops`; debugfs `lru_gen` criado.
- `mm/vmscan.o`, `mm/swap_state.o`, `mm/swapfile.o`, `mm/swap.o`, `mm/pagewalk.o`,
  `mm/workingset.o`, `fs/fuse/dev.o`, `kernel/sched/core.o`, `kernel/{fork,exit,exec}.o`
  compilam.

## 5. Entrega

- `patches/mglru/0001-mglru.patch` — consolidação (47 arquivos,
  +4307/-402), gerada via `git add -A` + `git diff --cached` da árvore da base.
- `configs/droidspace.config`:
  ```
  CONFIG_LRU_GEN=y
  CONFIG_LRU_GEN_ENABLED=y
  # CONFIG_LRU_GEN_STATS is not set
  ```
- `.github/workflows/build-pulsar.yml` — notas de release atualizadas (MGLRU).

## 6. Estrutura local

- `/tmp/dk/` — árvore da base com o MGLRU aplicado (base `68d2ad5c8`).
- `/tmp/dk/mglru-wip.patch` — patch gerado.
- `/tmp/dk/vmscan_newblock.txt`, `/tmp/dk/vmscan_new.c`,
  `/tmp/dk/vmscan_orig_backup.c` — backups/regiões do vmscan.c durante a
  reaplicação manual.
