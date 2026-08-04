# Backport do zsmalloc moderno (consolidate locks) para o MagicTime 4.19

## 1. Objetivo

Consolidar o sistema de locks do zsmalloc no kernel MagicTime 4.19 (POCO F3 /
alioth, branch `magictime-tiny`), passando do modelo antigo (lock por zspage via
`migrate_write_lock()`) para o modelo moderno (spinlock único por pool).

## 2. Fonte do backport

- Repo: `yamaizano/android_kernel_xiaomi_scarlet` (Redmi Note 8 / scarlet,
  base CAF 4.19.288 Xiaomi).
- Branch: `scarlet` (HEAD).
- Série aplicada: commits "BACKPORT: zsmalloc: ..." extraídos via
  `git log --oneline -- mm/zsmalloc.c` (165 commits, ~25 da série de locks).

### Commits-chave da série (em ordem de aplicação)

| Commit | Descrição |
|--------|-----------|
| `4491e1b23c15` | BACKPORT: zsmalloc: replace per zpage lock with pool->migrate_lock |
| `1ac4ec099b70` | BACKPORT: zsmalloc: consolidate zs_pool's migrate_lock and size_class's locks |
| `749767724864` | BACKPORT: zsmalloc: rework compaction algorithm |
| `0bbc93f479f7` | BACKPORT: zsmalloc: reset compaction source zspage after putback |
| `8d652f438ea4` | BACKPORT: zsmalloc: implement per fullness group stats |
| `e29cf289a841` | BACKPORT: zsmalloc: remove migrate_write_lock_nested |

### Commit revertido

- `5dcd5e179b87` "allow only one active pool compaction context" foi
  **revertido** por `c1027ba10dd7` — o resultado final mantém múltiplos
  contextos de compactação.

## 3. Mudanças no código

### `mm/zsmalloc.c` (2648 → 2404 linhas, diff ~1058 linhas)

- `struct size_class`: **removido** `spinlock_t lock` (antes era 1 lock por
  classe de tamanho). Agora só contém `stats` e metadados de geometria.
- `struct zs_pool`: **adicionado** `spinlock_t lock` único (antes só tinha
  `migrate_lock` como rw_lock; agora é spinlock único consolidado).
- Removidas: `migrate_write_lock()`, `migrate_write_unlock()`,
  `is_zspage_isolated()`, `testpin_tag()`, `trypin_tag()`, `pin_tag()`,
  `unpin_tag()`, fullness enums → migrados para `int` index.
- Adicionadas: `obj_allocated()`, `obj_to_page()`,
  `class_stat_inc/dec/get()`, `get_fullness_group()` retorna int index,
  `zs_pool_stat` com contadores por class + per-fullness.
- `zs_create_pool()` / `zs_destroy_pool()`: agora inicializa/destrói o
  `spinlock_t pool->lock`.
- Compactação reescrita: algoritmo de source-first com `compaction_src`,
  `compaction_dst` por zspage, sem migração isolada por zspage.

### `include/linux/zsmalloc.h`

- Removida nota "no effect when PGTABLE_MAPPING is selected".
- Adicionada declaração `unsigned int zs_lookup_class_index(...)`.
- `struct zs_pool_stats` simplificada.

## 4. O que NÃO foi alterado

- **`drivers/block/zram/`**: o zram do timisong tem writeback, memory tracking,
  dedup e per-cpu streams (CONFIG_ZRAM_WRITEBACK, ZRAM_MEMORY_TRACKING).
  O zram do scarlet tem features diferentes (CONFIG_ZRAM_DEF_COMP, module_param
  default_compressor) — **não aplicadas** para evitar conflitos.
- **Outros arquivos**: apenas `mm/zsmalloc.c` e `include/linux/zsmalloc.h`.

## 5. Validação

- `git apply --check`: patch aplica limpo em checkout fresco de `e764f7231`.
- **clang -fsyntax-only**: não viável localmente (Termux sem headers gerados
  do kernel; o `make` de headers requer ELF host tools).
- **CI build** (Clang 20, GitHub Actions): é a validação definitiva — o
  workflow aplica `patches/*/*.patch` e compila o kernel completo.

## 6. Config necessária

Nenhuma mudança adicional — `CONFIG_ZSMALLOC=y` já está habilitada no
fragment `droidspaces.config` e no `magictime-common.config`.

## 7. Ganho esperado

- **Redução de contenção de locks** sob carga intensiva de swap/zram: o modelo
  antigo bloqueava por zspage inteira durante compactação; o novo usa um único
  spinlock por pool, com operações de read-path lock-free via stat counters.
- **Compaction mais eficiente**: algoritmo source-first evita fragmentação
  e reduz latência de alloc sob pressão.
- **Estabilidade**: série amplamente testada no AOSP/CAF 4.19 (Xiaomi Redmi
  Note 8, 4.19.288) com 165 commits de suporte ao zsmalloc.
