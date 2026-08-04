# zram: default compressor zstd

## Contexto

No POCO F3/alioth (Android 17 GSI), o `mmd_setup` (Memory Management Daemon do
AOSP) configura o zram no boot:

- `mmd.zram.size` — default **50% da RAM** (6GB → 3GB). O tamanho é escolha
  de userspace (sysfs `disksize`); o kernel não tem default (zram nasce em 0).
- `mmd.zram.comp_algorithm` — **não setada** no device → o mmd usa o **default
  do kernel**. No timisong esse default era `lz4` (hardcoded em
  `drivers/block/zram/zram_drv.c`).

Sessão 2026-08-04: o script de boot (Termux:Boot `zram.sh`) tentava reconfigurar
zram0 para 4GB+zstd após o mmd_setup, mas falhava porque o `swapoff` não
terminava em 45s (sistema ainda carregando apps no boot) → reset rc=1 → zram
voltava a 3GB/lz4.

## Decisão

Adotar **zstd via kernel + aceitar 3GB** (50% da RAM, o sweet spot analisado na
seção 15.2 do BUILD-KERNEL-MAGICTIME-DROIDSPACE.md). O script de boot foi
removido.

## O patch

`0001-zram-default-compressor-zstd.patch` (1 hunk, `drivers/block/zram/zram_drv.c`):

```diff
-static const char *default_compressor = "lz4";
+static const char *default_compressor = "zstd";
```

Como `mmd.zram.comp_algorithm` não é setada, o mmd_setup passa a usar zstd no
boot — sem nenhum script. Requisito: `CONFIG_CRYPTO_ZSTD=y` (já no fragment
`configs/droidspaces.config`).

## Validação

- `git apply --check` limpo na base `e764f7231` (checkout fresco).
- Após flash: `cat /sys/block/zram0/comp_algorithm` deve mostrar `[zstd]` em
  todo boot; `disksize` = 3GB (50% da RAM, config do mmd).

## Nota

Se um dia quiser trocar o tamanho, é prop de userspace (`mmd.zram.size`, ex.
`75%`), não kernel — precisaria ser setada antes do `mmd_setup` rodar (~20s no
boot), o que via Termux:Boot não é viável (roda ~2min depois).
