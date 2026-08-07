# BUILD — Backport openat2 / clone3 / faccessat2 para FEX-Emu (POCO F3 / alioth)

Registro completo do trabalho de backport dos syscalls que o **FEX-Emu** exige
no kernel **Pulsar 4.19.404** (base `xiaomi_sm8250_kernel_e404`, branch
`staging-bpf`, commit `68d2ad5c8`), compilado via GitHub Actions e distribuído
em release AnyKernel.

---

## 1. Problema

O FEX-Emu (emulador x86/x86-64 usermode em AArch64) recusava-se a funcionar no
device (POCO F3 / alioth) com o kernel Pulsar 4.19.404. O kernel base já
possuía por graft 5.10/5.15 os syscalls:

| nr | syscall |
|----|---------|
| 434 | `pidfd_open` |
| 436 | `close_range` |
| 440 | `process_madvise` |
| 441 | `epoll_pwait2` |

Faltavam os syscalls exigidos pelo FEX moderno:

- **`openat2` (437)** — **crítico**: o FEX moderno usa `openat2(RESOLVE_IN_ROOT)`
  **incondicionalmente** para todo `open` via RootFS (`FileManager::Open/Openat`),
  sem fallback para ENOSYS (apenas EXDEV para magic links `/proc`).
- **`clone3` (435)** — usado por glibc ≥ 2.34 (`pthread_create`) tanto no
  FEXLoader (nativo) quanto nos programas x86 guest.
- **`faccessat2` (439)** — registrado incondicionalmente pelo FEX; sem ele,
  `access()/faccessat2()` do guest retornavam `ENOSYS`. (`access()`/`faccessat()`
  do FEX usam `faccessat` normal, então era "nice-to-have", mas foi portado.)

FEX também imprime aviso "requires kernel 5.15 minimum" (não é recusa) — o
uname spoof do kernel cobre isso.

Diagnóstico: `memfd_create` (279) funcionava; seccomp descartado como causa.

---

## 2. O que foi portado

### 2.1 `patches/openat2/0001-namei-scoped-lookups.patch`

Série `work.openat2` (Aleksa Sarai, upstream v5.6) aplicada à base 4.19:

- `fs/namei.c`: `set_root`, `nd_jump_root`, `nd_jump_link`, `get_link`,
  `follow_dotdot(_rcu)`, `handle_dots`, `complete_walk`, `path_init`,
  `follow_managed` — suporte às flags de escopo:
  `LOOKUP_NO_SYMLINKS`, `LOOKUP_NO_MAGICLINKS`, `LOOKUP_NO_XDEV`,
  `LOOKUP_BENEATH`, `LOOKUP_IN_ROOT`, `LOOKUP_IS_SCOPED`,
  `LOOKUP_ROOT_GRABBED`, `LOOKUP_FAIL_ON_LAST_DOT`, `LOOKUP_JUMPED`.
- `fs/proc/base.c`, `fs/proc/namespaces.c`, `security/apparmor/apparmorfs.c`:
  chamadas atualizadas para os novos retornos de erro.
- `include/linux/namei.h`: flags de escopo + `#include <linux/fs.h>`.

Decisões de porta (diferenças vs 5.6):
- `handle_dots` escopado usa apenas `read_seqretry(&mount_lock, nd->m_seq)`
  (4.19 não tem `r_seq` no `nameidata`).
- `terminate_walk` da base já cobre root escopado (sem mudança).
- `complete_walk` preserva o hook vendor `success_walk_trace`.
- `set_root` de escopo retorna `-ENOTRECOVERABLE` no `WARN_ON` de
  `LOOKUP_IS_SCOPED` (igual 5.6).

### 2.2 `patches/openat2/0002-openat2-syscall.patch`

- `fs/open.c`:
  - refactor `build_open_flags()` + novo `build_open_how()` (valida `struct
    open_how`), `VALID_OPEN_FLAGS`/`VALID_RESOLVE_FLAGS`;
  - `do_sys_openat2()` (preserva o hook vendor `libperfmgr_redirect` no open;
    cast `(int)how->flags` mantido);
  - `SYSCALL_DEFINE4(openat2, ...)`;
  - **`faccessat2`**: `do_faccessat()` ganhou o parâmetro `flags`
    (`AT_EACCESS | AT_SYMLINK_NOFOLLOW | AT_EMPTY_PATH`), com
    `LOOKUP_EMPTY`/`LOOKUP_FOLLOW` e o override de creds condicionado a
    `!(flags & AT_EACCESS)` (ids reais vs efetivos); `SYSCALL_DEFINE4(faccessat2, ...)`.
- `fs/internal.h`: declaração de `do_faccessat` com 4 args.
- `include/linux/fcntl.h`: `VALID_RESOLVE_FLAGS`, `OPEN_HOW_SIZE_*`.
- `include/uapi/linux/fcntl.h`: `#include <linux/openat2.h>` +
  **`AT_EACCESS`** (não existia na base 4.19).
- **novo** `include/uapi/linux/openat2.h`: `struct open_how` +
  `RESOLVE_*` flags.
- `include/linux/syscalls.h`: fwd decls `struct open_how`/`struct clone_args`,
  protótipos `sys_openat2`, `sys_faccessat2`, `do_faccessat` (4 args).

### 2.3 `patches/openat2/0003-clone3-syscall.patch`

- `kernel/fork.c`: `clone3_args_valid()` + `SYSCALL_DEFINE2(clone3, ...)`
  usando `copy_struct_from_user()` e chamando o `_do_fork` antigo da 4.19:
  `args.stack + args.stack_size` (semântica `clone3_stack_valid` do v5.3).
- `include/uapi/linux/sched.h`: `struct clone_args` +
  `CLONE_ARGS_SIZE_VER0 64` + **`#include <linux/types.h>`** (fix `__aligned_u64`).
- `include/linux/sched/task.h`: `CLONE_LEGACY_FLAGS 0xffffffffULL`.
- `arch/arm64/include/asm/unistd32.h`: `__NR_clone3 435`,
  `__NR_openat2 437`, `__NR_faccessat2 439`.

### 2.4 `patches/openat2/0004-syscall-numbers.patch`

- `include/uapi/asm-generic/unistd.h`: `__NR_clone3 435`,
  `__NR_openat2 437`, `__NR_faccessat2 439` (+ tabela `__SYSCALL`).

### Resultado — syscalls do FEX agora presentes

`pidfd_open(434)`, `clone3(435)`, `close_range(436)`, `openat2(437)`,
`faccessat2(439)`, `process_madvise(440)`, `epoll_pwait2(441)`.

---

## 3. Problemas encontrados e corrigidos no processo

### 3.1 `git apply` falhava em `include/linux/syscalls.h` (offset de linhas)

O glob do workflow (`patches/*/*.patch`) aplica `dma_heaps`, `droidspaces`,
`io_uring` e `mglru` **antes** dos patches `openat2`. O `io_uring` insere
`struct io_uring_params;` logo após o contexto dos meus hunks, e o
`git apply` (fuzz 0, sem tolerância a offset) falhava:

```
error: patch failed: include/linux/syscalls.h:67
```

Os patches foram **regenerados contra o estado base + patches-prévios**
(`BEFORE` = commit `81d5f3fe` no clone local), com cada arquivo presente em
**um único** patch da série — a sequência inteira volta a aplicar limpa.

### 3.2 Erro de compilação `__aligned_u64`

`struct clone_args` usa `__aligned_u64`, mas a 4.19 não inclui
`linux/types.h` em `include/uapi/linux/sched.h`:

```
../include/uapi/linux/sched.h:65:2: error: unknown type name '__aligned_u64'
```

Corrigido adicionando `#include <linux/types.h>` no topo (igual upstream
v5.3/v5.6).

### 3.3 `AT_EACCESS` inexistente na 4.19

A base 4.19 do vendor não define `AT_EACCESS` no uapi `fcntl.h`. Adicionado
`#define AT_EACCESS 0x200` junto de `AT_SYMLINK_NOFOLLOW`.

---

## 4. Commits no repo

```
0e0371b faccessat2 (439): backport do syscall p/ FEX
82ab328 clone3: incluir linux/types.h no sched.h uapi (__aligned_u64)
84fa345 openat2/clone3: regenera patches contra base pos-patches previos
2ccea58 backport openat2(437) e clone3(435) - resolve flags namei
```

---

## 5. Builds (GitHub Actions)

Workflow `.github/workflows/build-pulsar.yml`: checkout do repo em
`droidspace/`, clone da base `staging-bpf`, `git submodule update --init`
(KernelSU), aplica `patches/*/*.patch` na ordem, instala o fragment
`configs/droidspace.config`, compila com Clang 20 (ZyCromerZ), empacota
AnyKernel, faz release.

| run | commit | resultado |
|-----|--------|-----------|
| 31172032572 | `2ccea58` | FAIL — patches: `syscalls.h:67` (offset pós-io_uring) |
| 31172626574 | `84fa345` | FAIL — compile `__aligned_u64` (sched.h) |
| 31172984270 | `82ab328` | CANCELADO (para incluir faccessat2) |
| 31173874341 | `0e0371b` | **SUCCESS** → release |

### Release

- **TAG:** `v1.0.0-20260807-1141`
- **ZIP:** `Pulsar-alioth-20260807-1141.zip`
- URL: https://github.com/otaviomorais/Pulsar-Kernel/releases/tag/v1.0.0-20260807-1141

---

## 6. Instalação e teste

1. Baixar `Pulsar-alioth-20260807-1141.zip`.
2. Flash via recovery (TWRP) — AnyKernel (imagem + dtb + dtbo).
3. Reboot e validar syscalls:
   ```sh
   # no device, via adb/terminal
   uname -a                                   # 4.19.404 (uname spoof ativo)
   # testar openat2/clone3/faccessat2 (ex.: strace um binário FEX ou:
   python3 - <<'EOF'
   import os, ctypes, sys
   libc = ctypes.CDLL(None, use_errno=True)
   for nr, name in [(437,'openat2'),(435,'clone3'),(439,'faccessat2')]:
       r = libc.syscall(nr, -100, b"/", 0, 0)
       print(name, "->", r, "errno:", ctypes.get_errno())
   EOF
   # -ENOSYS (=38) indica ausência; qualquer outro valor/retorno ok
   ```
4. Rodar o FEX:
   ```sh
   FEXBash -c "echo hello"        # smoke test
   FEXInterpreter /bin/ls         # ou FEXLoader
   ```
   Sinais de sucesso: FEX abre RootFS, cria threads (clone3) e executa
   binários x86 sem erro `ENOSYS` de `openat2`/`faccessat2`.
