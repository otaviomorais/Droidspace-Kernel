# MEMÓRIA COMPLETA - DESENVOLVIMENTO DROIDSPACE KERNEL v1.5.0 (ALIOTH)

* **Data:** 31/07/2026
* **Dispositivo Alvo:** Xiaomi POCO F3 / Redmi K40 / Mi 11X (`alioth` - Qualcomm Snapdragon 865 - SM8250)
* **Repositório:** [otaviomorais/Droidspace-Kernel](https://github.com/otaviomorais/Droidspace-Kernel)
* **Versão da Release:** `v1.5.0`

---

## 1. Resumo das Modificações Realizadas (Release v1.5.0 - Clean Build)

### A) Implementação e Migração Completa para ReSukiSU (`ReSukiSU/ReSukiSU`)
* **Motivo:** O repositório da árvore do kernel (`TIMISONG-dev/kernel_xiaomi_sm8250`) exige chamadas diretas a hooks manuais (`ksu_handle_execveat`, `ksu_handle_faccessat`, `ksu_handle_stat`, etc.) típicos de kernels Linux 4.19 Não-GKI (`alioth`).
* **Solução:** Migração completa para a árvore **ReSukiSU (`ReSukiSU/ReSukiSU`)** com suporte nativo a `CONFIG_KSU_MANUAL_HOOK=y` e `CONFIG_KSU_MULTI_MANAGER_SUPPORT=y`.
* **Vantagens do ReSukiSU:**
  1. Suporte ativo a Manual Hooks para kernels Linux 3.4+ a 4.19 Não-GKI.
  2. Suporte a Multi-Manager (funciona perfeitamente com KernelSU Manager oficial, ReSukiSU Manager, RKSU, MKSU e SukiSU).
  3. Suporte a Metamodules, App Profiles e compatibilidade aprimorada com Android 14+.

### B) Multi-Generational LRU (MGLRU) & Timer Tick 1000Hz
* **MGLRU (`CONFIG_LRU_GEN=y`):** Melhora o gerenciamento de memória RAM e previne congelamentos durante uso de containers (Winlator/Ludashi) e jogos.
* **1000Hz Timer Tick (`CONFIG_HZ_1000=y`):** Reduz a latência de entrada/toque no display e melhora o frametime em emuladores.

### C) Compressão ZSTD na ZRAM 6.44GB
* **Otimização:** ZRAM configurada nativamente em ZSTD (`CONFIG_ZRAM_DEF_COMP_ZSTD=y`), garantindo ganho significativo na taxa de compressão e velocidade.

### D) Emulação & Containers (NTSync + Winlator / Ludashi)
* Driver **NTSYNC** nativo (`/dev/ntsync` permissão `0666`) ativado para suporte a jogos via Wine/Proton.

---

## 2. Instruções de Instalação e Gerenciadores Suportados
1. **Flashing do Kernel:** Instalar a release ZIP `v1.5.0` via TWRP / OFRP / KernelSU Flasher.
2. **Gerenciadores Suportados:** ReSukiSU suporta o gerenciador oficial KernelSU Manager, ReSukiSU Manager, RKSU, etc.
3. **Instalação Limpa:** Se o root não aparecer imediatamente após o flash, limpe os dados do aplicativo gerenciador e reinicie o dispositivo.

---

## 3. Notas de Diagnóstico (01/08/2026)
* **Compatibilidade 4.19 Não-GKI:** `ReSukiSU` resolveu com precisão todos os símbolos de hooks manuais (`ksu_handle_*`) exigidos pela árvore do kernel `sm8250`.
