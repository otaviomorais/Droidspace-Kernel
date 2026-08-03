# Backport do io_uring (v5.1) para o MagicTime 4.19

Registro completo do backport do io_uring para o kernel MagicTime
(POCO F3 / alioth, Linux 4.19, branch `magictime-tiny` do
`TIMISONG-dev/kernel_xiaomi_sm8250`) e da entrega como patch no repo
`Droidspace-Kernel`.

## 1. Objetivo

Fornecer o io_uring para o kernel 4.19 do MagicTime, empacotado como patch
aplicável pelo CI e habilitado via fragment de configs DroidSpaces
(`CONFIG_IO_URING=y`).

## 2. Fonte do backport

- Fonte: mainline Linux **v5.1** (`torvalds/linux`), extraído via
  `git show v5.1:<file>` no clone parcial do kernel Xiaomi (fetch parcial da
  tag v5.1 + diff v5.0..v5.1).
- O io_uring 5.1 é **autocontido**: só `fs/io_uring.c` +
  `include/uapi/linux/io_uring.h` (io-wq e `include/linux/io_uring.h` só
  aparecem no 5.2). Não foi necessário portar io-wq.
- Base de aplicação: `e764f7231` (HEAD de `magictime-tiny`, commit
  "KernelSU: Update to 3.2").

## 3. Adaptações manuais para o 4.19

O 4.19 CAF do Xiaomi já tinha a maior parte das APIs; o que faltava:

| Item | Adaptação |
|---|---|
| `set_user_sigmask`/`restore_user_sigmask` | Portadas de `kernel/signal.c` v5.1 + declarações em `include/linux/signal.h` |
| `set_compat_user_sigmask` | Portada de `kernel/signal.c` v5.1; **declaração em `include/linux/compat.h`** (posição do v5.1 — `compat_sigset_t` não é visível no signal.h) |
| `get_current_ioprio()` | Não existe no 4.19 CAF; adicionada a versão v5.1 em `include/linux/ioprio.h` |
| `mmap_sem` → `mmap_lock` | 2 ocorrências em `fs/io_uring.c` (`io_uring_register`/buffered mmap pin) renomeadas |
| `f_op->iopoll` | Membro adicionado em `struct file_operations` (`include/linux/fs.h`, após `write_iter`) |
| `io_uring_get_socket()` | Protótipo + inline fallback em `include/linux/fs.h`; chamada em `net/unix/scm.c` (`unix_get_socket`) |
| `ITER_BVEC_FLAG_NO_REF` | Adicionado em `include/linux/uio.h` (bit 4; `READ`=0/`WRITE`=1 não colidem); mask em `iov_iter_type()`, helper `iov_iter_bvec_no_ref()` |
| `BIO_NO_PAGE_REF` | Bit 0 livre no 4.19; adicionado em `include/linux/blk_types.h` |
| `__bio_iov_bvec_add_pages()` | Portado para `block/bio.c` + dispatch por `iov_iter_is_bvec()` em `bio_iov_iter_get_pages()` + guardas em `bio_dirty_fn()`/`bio_check_pages_dirty()` |
| `bvec_nth_page()`/`mp_bvec_for_each_page()` | Adicionados em `include/linux/bvec.h`; **definidos como macros** (inline usaria `nth_page`, não visível em todo TU) |
| Syscalls 425/426/427 | `include/uapi/asm-generic/unistd.h` (após 424 `pidfd_send_signal`), `include/linux/syscalls.h`, `kernel/sys_ni.c` (`COND_SYSCALL`) |
| Kconfig | `init/Kconfig`: `config IO_URING` (default y; sem `select ANON_INODES` — anon_inodes é obj-y no 4.19) + `fs/Makefile` |

Nota: o kernel 5.1 já usa `mmap_lock` (sem adaptação adicional de lock) e o
4.19 CAF já tem `fput_many`, `vfs_fsync_range`, `import_iovec`, `iov_iter_bvec`,
`kiocb_set_rw_flags`, `kthread_parkme`, percpu_ref etc.

## 4. Verificações realizadas

- `clang -fsyntax-only` (clang 21 nativo Termux, arm64) com os include paths
  reais (`arch/arm64/include`, `out/arch/arm64/include/generated`, `include`,
  uapi, generated, `-include kconfig.h`/`compiler_types.h`): **limpo** para
  `fs/io_uring.c`, `block/bio.c`, `kernel/signal.c`, `net/unix/scm.c` e
  consumidores de headers (`lib/iov_iter.c`, `fs/aio.c`, `fs/eventpoll.c`,
  `block/blk-map.c`).
- Tentativa de build real via kbuild local: esbarrou em limitações do ambiente
  Termux (elf.h do bionic quebra host tools `modpost`/`sortextable`; clang
  Termux não aceita `-mabi=lp64`; erro de constraint em `jump_label.h`) —
  **não** é problema do port. A validação definitiva é o build do CI (Clang 20
  x86_64, GitHub Actions), que não sofre desses problemas de host.

## 5. Entrega no Droidspace-Kernel

- `patches/io_uring/0001-io_uring-5.1-backport.patch` — consolidado via
  `git diff e764f7231..HEAD` (17 arquivos, +3438/-11) e aplica limpo em
  checkout fresco (mesma base do CI).
- `configs/droidspaces.config`:
  ```
  CONFIG_IO_URING=y
  ```
- Notas de release do workflow atualizadas (io_uring v5.1 backport).

## 6. Builds CI

Pendente — primeiro push do `patches/io_uring` com `CONFIG_IO_URING=y`.

## 7. Estrutura local de trabalho

- `/data/data/com.termux/files/usr/tmp/opencode/io_uring-wt` — worktree final
  (base `e764f7231`, branch `io_uring-5.1-backport`, commit do port).
- `/data/data/com.termux/files/usr/tmp/opencode/io51/` — extrações do v5.1
  (io_uring.c, io_uring.h, uio.h, iov_iter.c, bvec.h, signal.c, signal.h,
  fs.h, scm.c, bio.c.diff, Kconfig, Makefile).
- `/data/data/com.termux/files/usr/tmp/opencode/timisong` — repo base 4.19
  (remote `torvalds` adicionado, tag v5.1 parcial para `git show v5.1:<file>`).
- `/data/data/com.termux/files/usr/tmp/opencode/Droidspace-Kernel` — repo de
  entrega.

## 8. Comandos úteis

```sh
# regenerar o patch consolidado a partir do worktree final
git -C io_uring-wt diff e764f7231..HEAD > Droidspace-Kernel/patches/io_uring/0001-io_uring-5.1-backport.patch

# validar aplicação em base fresca
git apply --check patches/io_uring/0001-io_uring-5.1-backport.patch
```
