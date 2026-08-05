<div align="center">

[**🇧🇷 Português**](README.md) · [**🇺🇸 English**](README.en.md)

</div>

<div align="center">

# ⚡ Pulsar Kernel

**Kernel de performance para POCO F3 / Xiaomi Mi 11 (alioth)**

Multi-Gen LRU · ntsync · BPF backports · KernelSU · io_uring

[![Release](https://img.shields.io/badge/release-v1.0.0-blue)](https://github.com/otaviomorais/Pulsar-Kernel/releases)
[![Build](https://img.shields.io/badge/build-GitHub%20Actions-2088FF)](https://github.com/otaviomorais/Pulsar-Kernel/actions)
[![License](https://img.shields.io/badge/license-GPL--2.0-lightgrey)](https://github.com/otaviomorais/Pulsar-Kernel/blob/main/README.md)

</div>

---

## ✨ Sobre

O Pulsar nasce de uma base SM8250 madura — ~79 releases acima do upstream
`4.19.325` — com **eBPF 5.10/5.15**, MGLRU nativo e suporte a Android 16/17.

Foi escolhida depois de testes diretos: é a única base testada com **USB/MTP
funcionando e fluidez superior** no conjunto do projeto.

## 🚀 Features

| Recurso | Descrição |
|---|---|
| **MGLRU** | Multi-Gen LRU backportado com eviction control — menos jank, multitarefa mais fluida |
| **ntsync** | Emulação de primitivas de sincronização do Windows — Wine/Proton/Winlator mais rápidos |
| **BPF 5.10/5.15 + spoof uname** | Suporte a ROMs Android 16/17 e tooling moderno |
| **KernelSU** | Root integrado, sem alterar o boot image externamente |
| **io_uring** | Backport v5.1 — I/O assíncrono de baixa latência |
| **zram + zstd** | Compressor zstd padrão — swap mais compacto e rápido |
| **CGROUPS (DroidSpaces)** | Device/PIDs/sched/freezer habilitados para o container Android |

## 📲 Instalação

1. Baixe o **AnyKernel3 zip** da [última release](https://github.com/otaviomorais/Pulsar-Kernel/releases)
2. Flash via **TWRP / recovery** (ou kernel flasher compatível)
3. Reinicie — pronto

> Dica: depois de reiniciar, confira o MGLRU ativo:
> `cat /sys/kernel/mm/lru_gen/enabled` → deve mostrar `0x0003`

## 🔨 Build

O build roda no **GitHub Actions** (`build-pulsar.yml`, disparo manual) ou manualmente:

```bash
export ARCH=arm64 LLVM=1 LLVM_IAS=1
make O=out HOSTCC=gcc PYTHON=python3 CROSS_COMPILE=aarch64-linux-gnu- vendor/alioth_defconfig
make O=out LLVM=1 LLVM_IAS=1 HOSTCC=gcc PYTHON=python3 CROSS_COMPILE=aarch64-linux-gnu- vendor/droidspace.config
make -j$(nproc) O=out LLVM=1 LLVM_IAS=1 HOSTCC=gcc PYTHON=python3 CROSS_COMPILE=aarch64-linux-gnu- \
  CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip
```

Os backports vão em `patches/` com registro em `BACKPORT.md` — cada um é
documentado e auditável.

## 📁 Estrutura

```
├── configs/            # fragmentos de config (droidspace.config)
├── patches/
│   ├── droidspaces/    # fix cgroup para o container Android
│   ├── io_uring/       # backport v5.1
│   └── mglru/          # backport MGLRU + registro
└── .github/workflows/  # build-pulsar.yml (GitHub Actions)
```

## 🙏 Créditos

- [**timisong**](https://github.com/TIMISONG-dev) — base MagicTime e template AnyKernel3
- [**kvsnr113**](https://github.com/kvsnr113) — fonte do kernel base SM8250 (staging-bpf)
- [**rsuntk**](https://github.com/rsuntk) — KernelSU
- [**ZyCromerZ**](https://github.com/ZyCromerZ) — toolchain Clang
- [**ravindu644**](https://github.com/ravindu644) — autor do DroidSpaces ([Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS)), a infraestrutura de container que guia as escolhas do kernel

## ⚠️ Aviso

Kernel de customização. **Use por sua conta e risco** — sempre faça backup
antes de flashear. Perda de dados, bootloop ou dano não são responsabilidade
do projeto.
