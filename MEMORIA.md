# 🧠 MEMÓRIA DO PROJETO - DROIDSPACE KERNEL (POCO F3 / ALIOTH - SM8250)

**Última Atualização:** 01 de Agosto de 2026  
**Status do Projeto:** 🟢 **v1.5.0 COMPILAÇÃO E RECURSOS 100% CONCLUÍDOS COM SUCESSO**  
**Repositório Oficial:** [otaviomorais/Droidspace-Kernel](https://github.com/otaviomorais/Droidspace-Kernel)  

---

## 📌 1. Visão Geral da Arquitetura

* **Dispositivo Alvo:** Xiaomi POCO F3 / Redmi K40 / Mi 11X (`alioth` - Qualcomm Snapdragon 865 - SM8250).
* **Kernel Base:** `TIMISONG-dev/kernel_xiaomi_sm8250` (branch: `magictime-new` - Linux 4.19).
* **Toolchain de Compilação:** `ZyCromerZ/Clang-20` (LLVM 20.0.0git) + prebuilt GCC 4.9 cross-compilers (`aarch64-linux-android-4.9` / `arm-linux-androideabi-4.9`).
* **Motor Root & Root Concealment:** **rsuntk/KernelSU (`main`) + SUSFS v1.5.5 (Kernel VFS Anti-Detection)**.
* **Driver de Sincronização:** **ntsync** (`/dev/ntsync` com permissões `0666` nativas para Wine/Proton/emuladores).
* **Gerenciamento de Memória:** **ZRAM de 6GB com algoritmo ZSTD + MGLRU (Multi-Generational LRU)**.
* **Frequência de Timer:** **1000Hz Timer Tick (`CONFIG_HZ_1000=y`)** para menor latência ao toque e emulação.
* **Suporte DroidSpaces / Containers:** Namespaces completos (PID, UTS, IPC, USER, NET), Cgroups v1/v2, OverlayFS e TMPFS POSIX ACL.

---

## 🛡️ 2. Motor Root & SUSFS Anti-Detection

### 2.1 Por que rsuntk/KernelSU + SUSFS?
* **rsuntk/KernelSU (`main`):** Fork ativamente mantido do KernelSU especificamente focado em suporte a kernels **Non-GKI Linux 4.19**, estabilidade do daemon `ksud`, suporte completo a permissões SELinux para Zygisk Next e integração de hooks de VFS. Resolveu as falhas de conexão de serviço do `zygisksu` (`Could not connect to service!`) enfrentadas no KernelSU-Next legacy.
* **SUSFS (Kernel Stealth Mount System):** Aplica patches na camada de VFS (Virtual File System) do Linux (`fs/susfs.c`, `include/linux/susfs.h`, `50_add_susfs_in_kernel-4.19.patch`).
* **Ocultação Inquebrável de Root:** O SUSFS oculta todas as tabelas de montagem (`/proc/self/mounts`, `/proc/self/mountinfo`), pastas de módulos e rastros do KernelSU de qualquer varredura em espaço de usuário, garantindo compatibilidade total com **bancos (Nubank, Itaú, Bradesco, etc.), carteiras e Play Integrity**.

### 2.2 Configuração Ativa no `configs/droidspaces.config`:
```config
CONFIG_KPROBES=y
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME_RELEASE=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
```

---

## ⚡ 3. Recursos de Performance & Sistema

### 3.1 Driver ntsync (`/dev/ntsync`)
* **Propósito:** Emulação de primitivas de sincronização do Windows NT no kernel do Linux para ganho massivo de FPS em Wine, Proton e emuladores (Mobox, Winlator, Horizon).
* **Permissão Nativa:** O nó do dispositivo é registrado em `patches/ntsync/ntsync.c` com `.mode = 0666`, permitindo leitura e escrita para todos os usuários sem requerer scripts root adicionais post-boot.

### 3.2 ZRAM de 6GB & Compressão ZSTD
* **Algoritmo:** `CONFIG_ZRAM_DEF_COMP_ZSTD=y` com suporte a `ZSTD_COMPRESS` e `ZSTD_DECOMPRESS`.
* **Mecanismo de Enforcing:**
  1. Injeção da regra post-boot `overlay.d/init.zram.rc` no ramdisk do AnyKernel (disparada ao concluir o boot `sys.boot_completed=1`).
  2. Substituição dinâmica de declarações `zramsize=` em arquivos `fstab*` para **6442450944 bytes (6GB)** no script AnyKernel.

---

## ⚙️ 4. Fluxo de CI/CD (GitHub Actions)

* **Arquivo de Workflow:** `.github/workflows/build.yml`
* **Gatilho:** `push` na branch `main` e `workflow_dispatch`.
* **Status da Última Compilação:** 🟢 **Run #53 (`30707842587`) - Concluído com Sucesso**.
* **Artefato Gerado:** `Droidspace-alioth-v1.0.0-2026-08-01_16-28-34.zip` (instalável via TWRP / OrangeFox).

---

## 📝 5. Histórico de Modificações e Soluções

1. **Correção de Sintaxe de Toolchain:** Harmonizados scripts de compilação locais (`build.sh` e `settings.sh`) com a infraestrutura do GitHub Actions.
2. **Integração do SUSFS em Linux 4.19:** Configurado download e aplicação automática dos patches VFS do `susfs4ksu` no workflow e script de build.
3. **Resolução de ZRAM Presa em 3GB:** Adicionado patch de fstab e script de overlay de ramdisk no AnyKernel para forçar 6GB ZSTD em qualquer ROM Android.
4. **Verificação de Permissões ntsync:** Confirmada permissão `0666` nativa no driver `ntsync.c`.
