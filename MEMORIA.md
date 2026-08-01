# MEMÓRIA COMPLETA - DESENVOLVIMENTO DROIDSPACE KERNEL v1.5.0 (ALIOTH)

* **Data:** 31/07/2026
* **Dispositivo Alvo:** Xiaomi POCO F3 / Redmi K40 / Mi 11X (`alioth` - Qualcomm Snapdragon 865 - SM8250)
* **Repositório:** [otaviomorais/Droidspace-Kernel](https://github.com/otaviomorais/Droidspace-Kernel)
* **Versão da Release:** `v1.5.0`

---

## 1. Resumo das Modificações Realizadas (Release v1.5.0 - Clean Build)

### A) Migração de Base do Kernel para `starscroch/kernel_xiaomi_sm8250` (`lineage-sunflower`)
* **Motivo:** A árvore `starscroch/kernel_xiaomi_sm8250` (base LineageOS-CLO) já possui o ReSukiSU e o NoMount integrados nativamente com todos os hooks manuais do SELinux (`sel_handle_status_ops`) e VFS já aplicados no código-fonte, além de otimizações pesadas de debloat e alocação de RAM.
* **Solução:** Migração para a nova base `starscroch/kernel_xiaomi_sm8250` (branch `lineage-sunflower`), mantendo todos os recursos do Droidspace (NTSYNC `/dev/ntsync` 0666, Namespaces, CGroups, OverlayFS, MGLRU, 1000Hz Timer Tick e ZRAM ZSTD 6.44GB).
* **Recursos do Kernel `starscroch`:**
  1. ReSukiSU integrado nativamente como submódulo.
  2. Suporte a NoMount (`CONFIG_NOMOUNT=y`).
  3. `min_free_kbytes` fixado em 32MB e Watermark Boosting desativado para evitar travamentos de RAM.
  4. Debloat completo (remoção do Qualcomm DCC v2, QCOM Logging e ajuste do GPU idle timeout para 58ms).

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
* **Base `starscroch` (`lineage-sunflower`):** ReSukiSU + NoMount nativos + NTSYNC ativado com sucesso.
