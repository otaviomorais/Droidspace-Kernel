# MEMÓRIA COMPLETA - DESENVOLVIMENTO DROIDSPACE KERNEL v1.2.0 (ALIOTH)

* **Data:** 31/07/2026
* **Dispositivo Alvo:** Xiaomi POCO F3 / Redmi K40 / Mi 11X (`alioth` - Qualcomm Snapdragon 865 - SM8250)
* **Repositório:** [otaviomorais/Droidspace-Kernel](https://github.com/otaviomorais/Droidspace-Kernel)
* **Versão da Release:** `v1.2.0`

---

## 1. Resumo das Modificações Realizadas

### A) Integração do Fork MKSU / RSUNT (Magic Mount KernelSU)
* **Repositório do Fork:** [LKDenchin/rsuntk-KernelSU](https://github.com/LKDenchin/rsuntk-KernelSU.git) (branch: `main`)
* **Arquivos alterados:**
  * [`settings.sh`](file:///data/data/com.termux/files/home/Droidspace-Kernel/settings.sh): adicionadas variáveis `KSU_REPO` e `KSU_BRANCH`.
  * [`build.sh`](file:///data/data/com.termux/files/home/Droidspace-Kernel/build.sh) & [`.github/workflows/build.yml`](file:///data/data/com.termux/files/home/Droidspace-Kernel/.github/workflows/build.yml): clonagem dinâmica do KSU, verificação compatível com Makefile/Kbuild e patches de compilação.
  * [`configs/droidspaces.config`](file:///data/data/com.termux/files/home/Droidspace-Kernel/configs/droidspaces.config): adicionada a flag `CONFIG_KSU_MANUAL_HOOK=y`.
* **Correção de Linker:** Injetado stub fraco `void __attribute__((weak)) ksu_handle_sys_reboot(int *cmd) { (void)cmd; }` no `KernelSU/kernel/ksu.c` para resolver dependências de chamadas manuais no kernel SM8250.

### B) Driver NTSYNC - Permissão `0666` Permanente (Não-Root)
* **Arquivo:** [`patches/ntsync/ntsync.c`](file:///data/data/com.termux/files/home/Droidspace-Kernel/patches/ntsync/ntsync.c)
* Mantida a definição `.mode = 0666` no struct `ntsync_misc` para o kernel Linux 4.19.
* **Efeito:** O nó de dispositivo `/dev/ntsync` é criado na inicialização com permissão `rw-rw-rw-` (`0666`) pelo `ueventd` do Android, permitindo acesso direto por aplicativos não-root (Winlator, Mobox, Horizon, etc.) com a variável de ambiente `WINE_NTSYNC=1`.

### C) Expansão da ZRAM para 6GB
* **Arquivo [`configs/droidspaces.config`](file:///data/data/com.termux/files/home/Droidspace-Kernel/configs/droidspaces.config):**
  ```ini
  CONFIG_SWAP=y
  CONFIG_ZRAM=y
  CONFIG_ZRAM_DEF_COMP_LZ4=y
  CONFIG_ZRAM_WRITEBACK=y
  ```
* **Arquivos [`build.sh`](file:///data/data/com.termux/files/home/Droidspace-Kernel/build.sh) e [`.github/workflows/build.yml`](file:///data/data/com.termux/files/home/Droidspace-Kernel/.github/workflows/build.yml):**
  Adicionada instrução de patching automática no `anykernel.sh` durante a montagem do ZIP:
  ```sh
  patch_fstab fstab.qcom "zramsize=" replace "zramsize=6442450944"
  patch_fstab fstab.default "zramsize=" replace "zramsize=6442450944"
  ```
* **Efeito:** Aloca **6GB** (6.442.450.944 bytes) de memória swap ZRAM com compressão ultrarrápida LZ4 ao instalar o kernel no Android.

---

## 2. Log de Commits e Builds no GitHub

* **Commit 1:** `b1cab3a` - feat: MKSU fork integration, NTSYNC 0666 devnode permission, 6GB ZRAM configuration
* **Commit 2:** `b6a42be` - fix: update KSU checkout check to support Makefile or Kbuild
* **Commit 3:** `da78d55` - fix: remove unsupported devnode field in miscdevice for kernel 4.19
* **Commit 4:** `562dde6` - fix: enable CONFIG_KSU_MANUAL_HOOK=y and add ksu_handle_sys_reboot weak stub for MKSU compatibility

---

## 3. Resultado da GitHub Action Build

* **Run ID:** `30606739568` (Status: **SUCCESS**)
* **Tag de Release criada:** `v1.2.0`
* **URL da Release:** [Release v1.2.0 - Droidspace Kernel](https://github.com/otaviomorais/Droidspace-Kernel/releases/tag/v1.2.0)
* **Download Direto (.zip):** [Droidspace-alioth-v1.2.0.zip](https://github.com/otaviomorais/Droidspace-Kernel/releases/download/v1.2.0/Droidspace-alioth-v1.2.0-2026-07-31_05-34-28.zip)

---

## 4. Instruções de Instalação e Uso
* **Gerenciador KSU Recomendado:** [RSUNT Manager APK](https://github.com/rsuntk/KernelSU/releases)
* **Ativação do NTSYNC no Winlator:**
  Adicionar variável em *Container Settings -> Environment Variables*: `WINE_NTSYNC = 1`
