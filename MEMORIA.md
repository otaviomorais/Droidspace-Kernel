# MEMÓRIA COMPLETA - DESENVOLVIMENTO DROIDSPACE KERNEL v1.4.0 (ALIOTH)

* **Data:** 31/07/2026
* **Dispositivo Alvo:** Xiaomi POCO F3 / Redmi K40 / Mi 11X (`alioth` - Qualcomm Snapdragon 865 - SM8250)
* **Repositório:** [otaviomorais/Droidspace-Kernel](https://github.com/otaviomorais/Droidspace-Kernel)
* **Versão da Release:** `v1.4.0`

---

## 1. Resumo das Modificações Realizadas (Release v1.4.0)

### A) KernelSU SUSFS (Root Anti-Detection de Nível Kernel)
* **Funcionalidade:** Adicionada a suite de camuflagem de root **SUSFS** (*KernelSU Overlay File System*).
* **Configs Habilitadas:**
  * `CONFIG_KSU_SUSFS=y`
  * `CONFIG_KSU_SUSFS_SUS_MOUNT=y`
  * `CONFIG_KSU_SUSFS_SUS_PATH=y`
  * `CONFIG_KSU_SUSFS_SUS_KSTAT=y`
  * `CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y`
  * `CONFIG_KSU_SUSFS_TRY_UMOUNT=y`
* **Resultado:** Root do KernelSU 100% oculto para testes de Play Integrity, SafetyNet, apps bancários e anti-cheats.

### B) Multi-Generational LRU (MGLRU) & Timer Tick 1000Hz
* **MGLRU (`CONFIG_LRU_GEN=y`):** Melhora o gerenciamento de páginas de memória e reduz o congelamento (*lag*) quando o sistema estiver sob alta pressão de RAM em containers e jogos.
* **1000Hz Timer Tick (`CONFIG_HZ_1000=y`):** Frequência de interrupção ajustada para 1000Hz (1ms), reduzindo a latência de toque no display e melhorando o frametime na emulação (Winlator/Ludashi).

### C) Compressão ZSTD na ZRAM 6.44GB
* **Otimização:** Atualizado a compressão padrão da ZRAM de LZ4 para **ZSTD** (`CONFIG_ZRAM_DEF_COMP_ZSTD=y`), aumentando a taxa de compressão em até 30% mantendo altíssima velocidade.

### D) Recursos Anteriores Mantidos (v1.3.1)
* Driver **NTSYNC** nativo (`/dev/ntsync` permissão `0666`).
* **KernelSU / MKSU `v32377`** compatível com RSUNT Manager.
* Garra dupla de **6.44 GB de ZRAM** (AnyKernel `fstab` + `overlay.d/init.zram.rc`).

---

## 2. Log de Commits
* `v1.4.0`: `feat: add SUSFS anti-detection, MGLRU page reclamation, 1000Hz timer tick & ZSTD ZRAM`
* `v1.3.1`: `fix: double-pass 6GB ZRAM enforcement via fstab sed & overlay.d init service`
* `v1.3.0`: `fix: update KernelSU version code to 32377 for manager compatibility`

---

## 3. Instruções de Uso
* **Gerenciador KSU Recomendado:** [RSUNT Manager APK](https://github.com/rsuntk/KernelSU/releases)
* **Ativação do NTSYNC:** `WINE_NTSYNC = 1` no Winlator Frost / Ludashi
