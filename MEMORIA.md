# MEMÓRIA COMPLETA - DESENVOLVIMENTO DROIDSPACE KERNEL v1.4.1 (ALIOTH)

* **Data:** 31/07/2026
* **Dispositivo Alvo:** Xiaomi POCO F3 / Redmi K40 / Mi 11X (`alioth` - Qualcomm Snapdragon 865 - SM8250)
* **Repositório:** [otaviomorais/Droidspace-Kernel](https://github.com/otaviomorais/Droidspace-Kernel)
* **Versão da Release:** `v1.4.1`

---

## 1. Resumo das Modificações Realizadas (Release v1.4.1)

### A) Remoção do SUSFS (Estabilização do Root KernelSU)
* **Correção:** Desabilitadas as flags do `CONFIG_KSU_SUSFS` que estavam causando interferência nos hooks de montagem e concessão de root do `ksud`.
* **Resultado:** Concessão de root limpa e imediata no RSUNT / MKSU Manager (`v32377`).

### B) Multi-Generational LRU (MGLRU) & Timer Tick 1000Hz
* **MGLRU (`CONFIG_LRU_GEN=y`):** Melhora a tomada de decisão da memória RAM e reduz o congelamento (*lag*) quando o sistema estiver sob alta pressão de uso em containers (Winlator/Ludashi) e jogos.
* **1000Hz Timer Tick (`CONFIG_HZ_1000=y`):** Frequência de interrupção ajustada para 1000Hz (1ms), reduzindo a latência de toque no display e melhorando o frametime na emulação.

### C) Compressão ZSTD na ZRAM 6.44GB
* **Otimização:** Atualizado a compressão padrão da ZRAM de LZ4 para **ZSTD** (`CONFIG_ZRAM_DEF_COMP_ZSTD=y`), aumentando a taxa de compressão em até 30% mantendo altíssima velocidade.

### D) Correção da Versão de Releases no CI/CD (GitHub Actions)
* **Correção:** Resolvido o travamento no rótulo `v1.0.0`. Agora a Action lê dinamicamente a versão em `settings.sh`, nomeando automaticamente os ZIPs e tags como `v1.4.0`, `v1.5.0`, etc.

### E) Emulação & Containers (NTSync + Winlator / Ludashi)
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
* `v1.4.0` (`a0adb27`): `fix: dynamically resolve release version from settings.sh (v1.4.0)` (CI Run #30648107520)
* `v1.4.0` (`0890520`): `feat: release v1.4.0 with SUSFS root-hide, MGLRU page reclamation, 1000Hz timer tick & ZSTD ZRAM`
* `v1.3.1`: `fix: double-pass 6GB ZRAM enforcement via fstab sed & overlay.d init service`
* `v1.3.0`: `fix: update KernelSU version code to 32377 for manager compatibility`

---

## 4. Instruções de Instalação e Uso
* **Gerenciador KSU Recomendado:** [RSUNT Manager APK](https://github.com/rsuntk/KernelSU/releases) (Assinatura SHA-256 esperada pelo kernel: `f415f4ed9435427e1fdf7f1fccd4dbc07b3d6b8751e4dbcec6f19671f427870b`).
* **Ativação do NTSYNC:** `WINE_NTSYNC = 1` nas variáveis do container.

---

## 5. Notas de Diagnóstico e Correções Rápidas (31/07/2026)
* **ZRAM ZSTD Fix:** Atualizado em `build.sh` a regra do `overlay.d/init.zram.rc` para forçar `zstd` e 6.44GB no boot. Comando de ativação imediata: `su -c "echo 1 > /sys/block/zram0/reset && echo zstd > /sys/block/zram0/comp_algorithm && echo 6442450944 > /sys/block/zram0/disksize && mkswap /dev/block/zram0 && swapon /dev/block/zram0 -p 32767"`.
* **KernelSU Profile Directory:** Criado `/data/adb/ksu/profile/selinux` (permissão `777`) para evitar falha no `ksud` ao salvar perfis de app no RSUNT Manager.
* **Assinatura do Gerenciador KSU:** O kernel rejeita APKs gerenciadoras cuja hash SHA-256 da chave não bata com `f415f4ed9435427e1fdf7f1fccd4dbc07b3d6b8751e4dbcec6f19671f427870b` (assinatura do RSUNT Manager padrão).

