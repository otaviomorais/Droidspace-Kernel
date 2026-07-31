# MEMÓRIA COMPLETA - DESENVOLVIMENTO DROIDSPACE KERNEL v1.4.0 (ALIOTH)

* **Data:** 31/07/2026
* **Dispositivo Alvo:** Xiaomi POCO F3 / Redmi K40 / Mi 11X (`alioth` - Qualcomm Snapdragon 865 - SM8250)
* **Repositório:** [otaviomorais/Droidspace-Kernel](https://github.com/otaviomorais/Droidspace-Kernel)
* **Versão da Release:** `v1.4.0` (Build Run `#30642013618` - **SUCCESS**)

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
* **MGLRU (`CONFIG_LRU_GEN=y`):** Melhora a tomada de decisão da memória RAM e reduz o congelamento (*lag*) quando o sistema estiver sob alta pressão de uso em containers (Winlator/Ludashi) e jogos.
* **1000Hz Timer Tick (`CONFIG_HZ_1000=y`):** Frequência de interrupção ajustada para 1000Hz (1ms), reduzindo a latência de toque no display e melhorando o frametime na emulação.

### C) Compressão ZSTD na ZRAM 6.44GB
* **Otimização:** Atualizado a compressão padrão da ZRAM de LZ4 para **ZSTD** (`CONFIG_ZRAM_DEF_COMP_ZSTD=y`), aumentando a taxa de compressão em até 30% mantendo altíssima velocidade.

### D) Emulação & Containers (NTSync + Winlator / Ludashi)
* Driver **NTSYNC** nativo (`/dev/ntsync` permissão `0666`) 100% verificado e funcionando no **Winlator Frost** e **Winlator Ludashi**.
* Proton 11 NTSync (`11.0-2-arm64ec`) e Proton 10.99 NTSync (`10.0.99-arm64ec+ntsync`) integrados e prontos no ambiente.

---

## 2. Roteiro / Backports Planejados para a Versão v1.5.0
1. **WireGuard Nativo (`CONFIG_WIREGUARD=y`):** Backport do driver de VPN acelerado por hardware (Linux 5.6+).
2. **Otimizações Binder IPC (SultanXDA):** Redução da latência de troca de mensagens entre Android e Winlator.
3. **Schedutil Fast-Ramp:** Escalamento de frequência de CPU responsivo para evitar drops de FPS em emuladores.
4. **vDSO `clock_gettime`:** Aceleração de chamadas de relógio no espaço de usuário para o Wine/Proton.

---

## 3. Log de Commits
* `v1.4.0` (`0890520`): `feat: release v1.4.0 with SUSFS root-hide, MGLRU page reclamation, 1000Hz timer tick & ZSTD ZRAM` (CI Run #30642013618: **SUCCESS**)
* `v1.3.1`: `fix: double-pass 6GB ZRAM enforcement via fstab sed & overlay.d init service`
* `v1.3.0`: `fix: update KernelSU version code to 32377 for manager compatibility`

---

## 4. Instruções de Instalação e Uso
* **Gerenciador KSU Recomendado:** [RSUNT Manager APK](https://github.com/rsuntk/KernelSU/releases)
* **Ativação do NTSYNC:** `WINE_NTSYNC = 1` nas variáveis do container.
