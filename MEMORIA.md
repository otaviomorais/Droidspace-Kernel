# MEMÓRIA COMPLETA - DESENVOLVIMENTO DROIDSPACE KERNEL v1.3.1 (ALIOTH)

* **Data:** 31/07/2026
* **Dispositivo Alvo:** Xiaomi POCO F3 / Redmi K40 / Mi 11X (`alioth` - Qualcomm Snapdragon 865 - SM8250)
* **Repositório:** [otaviomorais/Droidspace-Kernel](https://github.com/otaviomorais/Droidspace-Kernel)
* **Versão da Release:** `v1.3.1`

---

## 1. Resumo das Modificações Realizadas

### A) Correção Definitiva da Expansão ZRAM para 6GB
* **Problema Encontrado:** A tentativa anterior usava `patch_fstab fstab.qcom "zramsize=" replace "zramsize=..."` que falhava no AnyKernel3 por sintaxe incompatível, mantendo o tamanho original de ZRAM da ROM.
* **Soluções Aplicadas (Dupla Garantia):**
  1. **Varredura e Subtituição Universal de `fstab` no AnyKernel:**
     Ao instalar o ZIP, o `anykernel.sh` busca todos os arquivos de fstab (`$ramdisk/fstab*`, `/vendor/etc/fstab*`, `/system/etc/fstab*`) e executa `sed -i -E 's/zramsize=[0-9%]+/zramsize=6442450944/g'` ajustando a ZRAM para exatamente 6.44GB.
  2. **Injeção de Script de Inicialização (`overlay.d/init.zram.rc`):**
     Injetado o script no ramdisk para que no evento `on property:sys.boot_completed=1`, a ZRAM seja verificada e reajustada para 6442450944 bytes caso alguma configuração da ROM tente sobrescrever o valor.

### B) Atualização da Versão Interna do KernelSU para 32377 (`v32377`)
* Patcheado `KernelSU-Next/kernel/ksu.h` para forçar `#define KSU_VERSION 32377` e `#define KERNEL_SU_VERSION 32377`.
* Patcheado `KernelSU-Next/kernel/Makefile` para definir `-DKSU_VERSION=32377`.
* O gerenciador KernelSU / MKSU reconhece a versão como **32377** (compatível).

### C) Driver NTSYNC - Permissão `0666` Permanente (Não-Root)
* Nó `/dev/ntsync` criado com permissão `rw-rw-rw-` (`0666`) para apps como Winlator (`WINE_NTSYNC=1`).

---

## 2. Autenticação e Disparo de Builds
* Token PAT do GitHub configurado e gravado com sucesso no helper de credenciais (`~/.git-credentials`).

---

## 3. Log de Commits
* `v1.3.1`: `fix: double-pass 6GB ZRAM enforcement via fstab sed & overlay.d init service`
* `v1.3.0`: `fix: update KernelSU version code to 32377 for manager compatibility`

---

## 4. Instruções de Instalação e Uso
* **Gerenciador KSU Recomendado:** [RSUNT Manager APK](https://github.com/rsuntk/KernelSU/releases)
* **Ativação do NTSYNC no Winlator:** Variável em *Container Settings -> Environment Variables*: `WINE_NTSYNC = 1`
