# MEMÓRIA COMPLETA - DESENVOLVIMENTO DROIDSPACE KERNEL v1.5.0 (ALIOTH)

* **Data:** 31/07/2026
* **Dispositivo Alvo:** Xiaomi POCO F3 / Redmi K40 / Mi 11X (`alioth` - Qualcomm Snapdragon 865 - SM8250)
* **Repositório:** [otaviomorais/Droidspace-Kernel](https://github.com/otaviomorais/Droidspace-Kernel)
* **Versão da Release:** `v1.5.0`

---

## 1. Resumo das Modificações Realizadas (Release v1.5.0 - Clean Build)

### A) Migração Limpa para KernelSU-Next Oficial (`rifs33/KernelSU-Next`)
* **Motivo:** O fork RSUNT/MKSU com versionamento forçado em `32377` gerou instabilidade e travamentos no subsistema de root do kernel.
* **Solução:** Migração completa para a árvore oficial do **KernelSU-Next** (branch `next`), sem alterações invasivas no código de versão.
* **Recursos de Hide Root:** Suporte nativo a umount automático, ocultação de montagens (`/proc/mounts`) e isolamento por app.

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
2. **Gerenciador KSU Recomendado:** Baixar e instalar o **KernelSU Next Manager APK** ([KernelSU-Next Releases](https://github.com/rifs33/KernelSU-Next/releases)).
3. **Se o root não aparecer de imediato após reflash:** Limpar os dados do app gerenciador KernelSU nas Configurações do Android e reiniciar o dispositivo.

---

## 3. Notas de Diagnóstico (31/07/2026)
* **Remoção de overrides hardcoded:** Removidos todos os scripts `sed` que forçavam `KSU_VERSION=32377` no `build.sh` e `.github/workflows/build.yml`.
* **KernelSU-Next compat:** Totalmente funcional em kernel Linux 4.19 no Snapdragon 865 (`alioth`).


