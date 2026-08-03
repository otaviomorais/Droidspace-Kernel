# Backport do Multi-Gen LRU (MGLRU) para o MagicTime 4.19

Registro completo do trabalho de backport do MGLRU para o kernel MagicTime
(POCO F3 / alioth, Linux 4.19, branch `magictime-tiny` do
`TIMISONG-dev/kernel_xiaomi_sm8250`) e da entrega como patches no repo
`Droidspace-Kernel`.

## 1. Objetivo

Fornecer o Multi-Gen LRU para o kernel 4.19 do MagicTime, empacotado como
patches aplicáveis pelo CI, e habilitado via fragment de configs DroidSpaces.

## 2. Fonte do backport

- Repo: `AlcatrazDev-Android-Devices/kernel_lge_sm8250`
  (mesma base CAF 4.19 qcom sm8250; cherry-picks FROMLIST do Google com
  "Bug: 228114874").
- Cadeia linear: `53da10c..28c7e93ce04cbe1dfabe3a02a149a7b3c09ae1ad`.
- Série: 29 commits:
  - 11 refactors de LRU API (migração para a API 5-arg/add-page por lruvec)
  - 2 commits de `arch_has_hw_pte_young` / NONLEAF_PMD_YOUNG
  - 10 FROMLIST do MGLRU
  - `42a4992` (fix qcom), `0acd39e` (IRQ-off), `28c7e93` (SPF aware)

### Commit removido da série

- `833e95e` "mm/vmscan: Update the page scan prioritiy" (tweak Motorola) foi
  **removido** — incompatível; o MagicTime já usa a variante AOSP/upstream de
  `get_nr_to_scan`.

### Patch 0030 (SPF aware) — SKIP

- `CONFIG_SPECULATIVE_PAGE_FAULT=n` em
  `arch/arm64/configs/vendor/xiaomi/sm8250-common.config:37` e o código SPF não
  existe no MagicTime.

## 3. Fluxo de aplicação

- `git apply --reject` + resolução manual dos `.rej` (o `--3way` não funciona
  nos clones parciais — blobs indisponíveis).
- Timisong está na API antiga 3-arg
  (`add_page_to_lru_list(page, lruvec, lru)`); os 14 patches de refactor eram
  necessários e aplicaram.
- Item 0006 corrigido manualmente (whitespace no hunk de
  `include/linux/mmzone.h`, `-     */` → `-\t */`).
- Shim `cpu_has_hw_af()` existe em `arch/arm64/include/asm/cpufeature.h:599`;
  o define `arch_has_hw_pte_young cpu_has_hw_af` compila (cpufeature.h chega via
  `asm/pgtable-prot.h`).

## 4. Resoluções manuais de rejects

| Arquivo | Resolução |
|---|---|
| `mm/gup.c` | hunk CAF-LG inexistente no Xiaomi (SKIP) |
| `arch/arm64/include/asm/pgtable.h` | adicionado `#define arch_has_hw_pte_young cpu_has_hw_af` (~linha 821) |
| `arch/arm64/include/asm/pgtable-prot.h` | suporte NONLEAF_PMD_YOUNG |
| `fs/fuse/dev.c` | `LRU_GEN_MASK \| LRU_REFS_MASK` em `fuse_check_page()` |
| `mm/swapfile.c` (`unuse_mm`) | `activate_page()` envolto por `if (!lru_gen_enabled())`, mantendo `mmap_read_trylock`/`mmap_read_lock` do Xiaomi |
| `mm/workingset.c` | removido `eviction >>= bucket_order` de `pack_shadow()` (mantém variante `EVICTION_MASK`/xarray do Xiaomi) |
| `include/linux/cgroup.h` (`#else /* !CONFIG_CGROUPS */`) | stubs `cgroup_lock() {}` / `cgroup_unlock() {}` |
| `mm/swap.c` (`lru_cache_add_active_or_unevictable`) | `SetPageActive(page)` condicionado a `!lru_gen_enabled()` |

## 5. Corretagens encontradas pelo CI (build real, Clang 20)

O CI rodou 3 builds; os 3 problemas abaixo só o compilador real detectou
(diferenças LG-sm8250 vs Xiaomi/MagicTime):

1. **`mmap_sem` → `mmap_lock`**
   `mm/vmscan.c` `walk_mm()` usava `down_read_trylock(&mm->mmap_sem)` /
   `up_read(&mm->mmap_sem)`; o MagicTime usa a nomenclatura renomeada
   (`mmap_lock`). Erro: `no member named 'mmap_sem'`.

2. **`radix_tree_exceptional_entry` → `xa_is_value`**
   O MagicTime já usa a API transicional XArray: `i_pages` é `struct xarray`
   (via `#define radix_tree_root xarray`) e `radix_tree_exceptional_entry` não
   existe. Corrigido em `mm/memory.c` (lru_gen_swap_refault) e `mm/swap_state.c`
   (3 usos). Erro: `implicit declaration of function 'radix_tree_exceptional_entry'`.

3. **Export de `__radix_tree_create`**
   O `__add_to_swap_cache()` refatorado (param `shadowp`) usa
   `__radix_tree_create()`; no MagicTime ela era `static` em `lib/radix-tree.c`.
   Corrigido: função não-static + protótipo em `include/linux/radix-tree.h`
   (mesmo estado da LG).

## 6. Verificações realizadas

- Sem `.rej`/`.orig`/marcadores de conflito em mm/fs/include/kernel.
- Sem chamadas 3-arg remanescentes.
- Hooks `lru_gen_add_mm/del_mm/use_mm/migrate_mm` em kernel/fork.c,
  kernel/exit.c, kernel/sched/core.c, fs/exec.c.
- `lru_gen_enabled()` presente; `DEFINE_STATIC_KEY_ARRAY_{TRUE,FALSE}
  (lru_gen_caps, NR_LRU_GEN_CAPS)` em mm/vmscan.c:2575-2577.
- `mm/Kconfig:840/849/855` com `config LRU_GEN`, `LRU_GEN_ENABLED`,
  `LRU_GEN_STATS`.
- `mem_cgroup_trylock_pages`/`unlock_pages` nas duas variantes (CONFIG_MEMCG e
  não) em include/linux/memcontrol.h.
- `lru_gen_init_memcg`/`exit_memcg` declarados em include/linux/mmzone.h e
  definidos em mm/vmscan.c.
- `struct lru_gen_mm_walk` em include/linux/mmzone.h:401; `mm_walk` como
  ponteiro em `struct reclaim_state` (include/linux/swap.h:133, local do
  MagicTime) e storage em `pg_data_t` (mmzone.h:967).
- Todos os símbolos auditados existentes no MagicTime:
  `cpus_read_lock/unlock`, `static_branch_{enable,disable}_cpuslocked`,
  `get_online_mems/put_online_mems`, `pgdat_memcg_congested` (static em
  vmscan.c), `mem_cgroup_get_nr_swap_pages`, `mem_cgroup_from_id`,
  `mem_cgroup_online`, `mem_cgroup_attach`, `mem_cgroup_swappiness`,
  `SWAP_ADDRESS_SPACE_SHIFT`, `xa_is_value`, `radix_tree_lookup`,
  `radix_tree_deref_slot_protected`, `__radix_tree_replace`, etc.

## 7. Entrega no Droidspace-Kernel

- `patches/mglru/0001-mglru.patch` — consolidação final (47 arquivos,
  +4330/-398), gerada via `git diff` da base `e764f7231` (HEAD de
  `magictime-tiny` = `origin/magictime-tiny`) e aplica limpa em checkout fresco.
- `configs/droidspaces.config`:
  ```
  CONFIG_LRU_GEN=y
  CONFIG_LRU_GEN_ENABLED=y
  ```
- `.github/workflows/build-kernel.yml` — passo "Apply ntsync patch" generalizado
  para aplicar todos os `patches/*/*.patch` em ordem:
  ```sh
  shopt -s nullglob
  for patch in "$GITHUB_WORKSPACE"/droidspace/patches/*/*.patch; do
    git apply --verbose "$patch"
  done
  ```
  Notas de release atualizadas (adicionado "Multi-Gen LRU (MGLRU) backport").
- `patches/README.md` — documenta o layout de patches e a origem do mglru.

## 8. Builds CI

| Commit | Resultado | Observação |
|---|---|---|
| `c3d4b77` | failure | `mmap_sem` (mm/vmscan.c:3631/3637) |
| `25ab372` | failure | `radix_tree_exceptional_entry` (mm/memory.c:2872) |
| `8828b96` | **success** | 25 min; release criada automaticamente |

- Run final: `30777554751` (2026-08-03T01:43Z → 02:08Z)
- Release: `kernel-20260803-0208`
  - Zip: `MagicTime-alioth-Droidspace-20260803-0208.zip`
  - URL: https://github.com/otaviomorais/Droidspace-Kernel/releases/tag/kernel-20260803-0208

## 9. Estrutura local de trabalho

- `/data/data/com.termux/files/usr/tmp/opencode/timisong-mglru` — worktree final
  com o MGLRU aplicado (base `e764f7231`), espelho do patch consolidado.
- `/data/data/com.termux/files/usr/tmp/opencode/mglru-patches/0001-mglru.patch` —
  patch gerado.
- `/data/data/com.termux/files/usr/tmp/opencode/mglru-src` — clone parcial do LG
  (cadeia `53da10c..28c7e93`).
- `/data/data/com.termux/files/usr/tmp/opencode/mglru-test-check` — worktree
  fresco usado para validar `git apply` + comparação de árvores.
- `/data/data/com.termux/files/usr/tmp/opencode/rej-capture/` — cópias dos
  rejects resolvidos.
- `/data/data/com.termux/files/usr/tmp/opencode/Droidspace-Kernel` — repo de
  entrega (main atualizada: `8828b96`).
- `/data/data/com.termux/files/usr/tmp/opencode/ci-logs{,2,3}.zip` + `ci-logs/`
  — logs dos builds baixados da API do GitHub (via token de
  `~/.git-credentials`).

## 10. Comandos úteis

```sh
# regenerar o patch consolidado a partir do worktree final
git -C timisong-mglru add -A
git -C timisong-mglru diff --cached > mglru-patches/0001-mglru.patch

# validar aplicação em base fresca
git apply --check patches/mglru/0001-mglru.patch

# baixar logs de um run do CI (com token)
curl -sL -H "Authorization: token <token>" \
  -o logs.zip "https://api.github.com/repos/otaviomorais/Droidspace-Kernel/actions/runs/<RUN_ID>/logs"
```
