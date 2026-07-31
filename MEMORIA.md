# MEMÓRIA COMPLETA - DESENVOLVIMENTO DROIDSPACE KERNEL v1.3.0 (ALIOTH)

* **Data:** 31/07/2026
* **Dispositivo Alvo:** Xiaomi POCO F3 / Redmi K40 / Mi 11X (`alioth` - Qualcomm Snapdragon 865 - SM8250)
* **Repositório:** [otaviomorais/Droidspace-Kernel](https://github.com/otaviomorais/Droidspace-Kernel)
* **Versão da Release:** `v1.3.0`

---

## 1. Resumo das Modificações Realizadas

### A) Atualização da Versão Interna do KernelSU para 32377 (`v32377`)
* **Problema:** O gerenciador KernelSU / MKSU reportava a versão `12066` do KernelSU (devido à contagem de commits em git shallow fetch `--depth=1`), que era considerada baixa / incompatível pelo APK do KernelSU Manager.
* **Solução:**
  * Patcheado `KernelSU-Next/kernel/ksu.h` para forçar `#define KSU_VERSION 32377` e `#define KERNEL_SU_VERSION 32377`.
  * Patcheado `KernelSU-Next/kernel/Makefile` para definir `-DKSU_VERSION=32377`.
* **Resultado:** O kernel agora reporta versão **32377** ao aplicativo gerenciador KernelSU/MKSU.

### B) Integração do Fork MKSU / RSUNT (Magic Mount KernelSU)
* **Repositório do Fork:** [LKDenchin/rsuntk-KernelSU](https://github.com/LKDenchin/rsuntk-KernelSU.git) (branch: `main`)
* **Arquivos alterados:**
  * [`settings.sh`](file:///data/data/com.termux/files/home/Droidspace-Kernel/settings.sh): versão atualizada para `1.3.0`.
  * [`build.sh`](file:///data/data/com.termux/files/home/Droidspace-Kernel/build.sh) & [`.github/workflows/build.yml`](file:///data/data/com.termux/files/home/Droidspace-Kernel/.github/workflows/build.yml): adicionados patches automáticos para a versão `32377`.
  * [`configs/droidspaces.config`](file:///data/data/com.termux/files/home/Droidspace-Kernel/configs/droidspaces.config): `CONFIG_KSU_MANUAL_HOOK=y`.
* **Correção de Linker:** Injetado stub fraco `void __attribute__((weak)) ksu_handle_sys_reboot(int *cmd) { (void)cmd; }` no `KernelSU/kernel/ksu.c`.

### C) Driver NTSYNC - Permissão `0666` Permanente (Não-Root)
* **Arquivo:** [`patches/ntsync/ntsync.c`](file:///data/data/com.termux/files/home/Droidspace-Kernel/patches/ntsync/ntsync.c)
* **Efeito:** O nó `/dev/ntsync` é criado na inicialização com permissão `rw-rw-rw-` (`0666`) pelo `ueventd` do Android, permitindo acesso direto por aplicativos não-root (Winlator, Mobox, Horizon, etc.) com a variável de ambiente `WINE_NTSYNC=1`.

### D) Expansão da ZRAM para 6GB
* **Arquivo [`configs/droidspaces.config`](file:///data/data/com.termux/files/home/Droidspace-Kernel/configs/droidspaces.config):** Swap ZRAM LZ4 habilitada.
* **AnyKernel Patch:** Aloca **6GB** (6.442.450.944 bytes) de ZRAM no boot.

---

## 2. Log de Commits
* **Commit v1.3.0:** `fix: update KernelSU version code to 32377 for manager compatibility`

---

## 3. Instruções de Instalação e Uso
* **Gerenciador KSU Recomendado:** [RSUNT Manager APK](https://github.com/rsuntk/KernelSU/releases)
* **Ativação do NTSYNC no Winlator:**
  Adicionar variável em *Container Settings -> Environment Variables*: `WINE_NTSYNC = 1`
