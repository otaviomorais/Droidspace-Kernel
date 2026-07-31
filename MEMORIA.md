# MEMÓRIA COMPLETA - DESENVOLVIMENTO DROIDSPACE KERNEL v1.5.0 (ALIOTH)

* **Data:** 31/07/2026
* **Dispositivo Alvo:** Xiaomi POCO F3 / Redmi K40 / Mi 11X (`alioth` - Qualcomm Snapdragon 865 - SM8250)
* **Repositório:** [otaviomorais/Droidspace-Kernel](https://github.com/otaviomorais/Droidspace-Kernel)
* **Versão da Release:** `v1.5.0`

---

## 1. Resumo das Modificações Realizadas (Release v1.5.0 - Clean Build)

### A) Migração Limpa para KernelSU Oficial (`tiann/KernelSU`)
* **Motivo:** O repositório da árvore do kernel (`TIMISONG-dev/kernel_xiaomi_sm8250`) possui chamadas diretas a hooks manuais (`ksu_handle_execveat`, `ksu_handle_faccessat`, `ksu_handle_sys_read`, `ksu_handle_stat`, `ksu_handle_input_handle_event`). O KernelSU-Next removeu essas funções em favor do KPROBES/GKI (gerando erro de compilação/linkagem), enquanto o **KernelSU oficial (tiann)** possui suporte total e nativo para kernels 4.19 Não-GKI (`alioth`).
* **Solução:** Migração limpa para a árvore oficial do **KernelSU (tiann/KernelSU - branch main)**.

### B) Multi-Generational LRU (MGLRU) & Timer Tick 1000Hz
* **MGLRU (`CONFIG_LRU_GEN=y`):** Melhora o gerenciamento de memória RAM e previne congelamentos durante uso de containers (Winlator/Ludashi) e jogos.
* **1000Hz Timer Tick (`CONFIG_HZ_1000=y`):** Reduz a latência de entrada/toque no display e melhora o frametime em emuladores.

### C) Compressão ZSTD na ZRAM 6.44GB
* **Otimização:** ZRAM configurada nativamente em ZSTD (`CONFIG_ZRAM_DEF_COMP_ZSTD=y`), garantindo ganho significativo na taxa de compressão e velocidade.

### D) Emulação & Containers (NTSync + Winlator / Ludashi)
* Driver **NTSYNC** nativo (`/dev/ntsync` permissão `0666`) ativado para suporte a jogos via Wine/Proton.

---

## 2. Instruções de Instalação e Instalação Limpa do Root
1. **Flashing do Kernel:** Instalar a release ZIP `v1.5.0` via TWRP / OFRP / KernelSU Flasher.
2. **Gerenciador KSU Recomendado:** Baixar e instalar o **KernelSU Manager APK** oficial ([KernelSU Releases](https://github.com/tiann/KernelSU/releases)).
3. **Se o root não aparecer de imediato após reflash:** Limpar os dados do app gerenciador KernelSU nas Configurações do Android e reiniciar o dispositivo.

---

## 3. Notas de Diagnóstico (31/07/2026)
* **Compatibilidade 4.19 Não-GKI:** `tiann/KernelSU` resolveu todos os símbolos de hooks manuais (`ksu_handle_*`) no kernel `sm8250`.


