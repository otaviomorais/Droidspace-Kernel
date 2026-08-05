<div align="center">

[**🇧🇷 Português**](README.md) · [**🇺🇸 English**](README.en.md)

</div>

<div align="center">

# ⚡ Pulsar Kernel

**Performance kernel for POCO F3 / Xiaomi Mi 11 (alioth)**

Multi-Gen LRU · ntsync · BPF backports · KernelSU · io_uring

[![Release](https://img.shields.io/badge/release-v1.0.0-blue)](https://github.com/otaviomorais/Pulsar-Kernel/releases)
[![Build](https://img.shields.io/badge/build-GitHub%20Actions-2088FF)](https://github.com/otaviomorais/Pulsar-Kernel/actions)
[![License](https://img.shields.io/badge/license-GPL--2.0-lightgrey)](https://github.com/otaviomorais/Pulsar-Kernel/blob/main/README.en.md)

</div>

---

## ✨ About

Pulsar is built on a mature SM8250 base — ~79 releases ahead of upstream
`4.19.325` — with **eBPF 5.10/5.15**, native MGLRU and Android 16/17 support.

## 🚀 Features

| Feature | Description |
|---|---|
| **MGLRU** | Multi-Gen LRU backport with eviction control — less jank, smoother multitasking |
| **ntsync** | Windows synchronization primitive emulation — faster Wine/Proton/Winlator |
| **BPF 5.10/5.15 + uname spoof** | Support for Android 16/17 ROMs and modern tooling |
| **KernelSU** | Built-in root, without externally modifying the boot image |
| **io_uring** | v5.1 backport — low-latency async I/O |
| **zram + zstd** | zstd compressor by default — smaller and faster swap |
| **CGROUPS (DroidSpaces)** | Device/PIDs/sched/freezer enabled for the Android container |

## 📲 Installation

1. Download the **AnyKernel3 zip** from the [latest release](https://github.com/otaviomorais/Pulsar-Kernel/releases)
2. Flash via **TWRP / recovery** (or a compatible kernel flasher)
3. Reboot — done

> Tip: after rebooting, check that MGLRU is active:
> `cat /sys/kernel/mm/lru_gen/enabled` → should show `0x0003`

## 🔨 Build

The build runs on **GitHub Actions** (`build-pulsar.yml`, manual trigger) or manually:

```bash
export ARCH=arm64 LLVM=1 LLVM_IAS=1
make O=out HOSTCC=gcc PYTHON=python3 CROSS_COMPILE=aarch64-linux-gnu- vendor/alioth_defconfig
make O=out LLVM=1 LLVM_IAS=1 HOSTCC=gcc PYTHON=python3 CROSS_COMPILE=aarch64-linux-gnu- vendor/droidspace.config
make -j$(nproc) O=out LLVM=1 LLVM_IAS=1 HOSTCC=gcc PYTHON=python3 CROSS_COMPILE=aarch64-linux-gnu- \
  CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip
```

Backports live in `patches/`, each documented and auditable in its own
`BACKPORT.md`.

## 📁 Structure

```
├── configs/            # config fragments (droidspace.config)
├── patches/
│   ├── droidspaces/    # cgroup fix for the Android container
│   ├── io_uring/       # v5.1 backport
│   └── mglru/          # MGLRU backport + documentation
└── .github/workflows/  # build-pulsar.yml (GitHub Actions)
```

## 🙏 Credits

- [**timisong**](https://github.com/TIMISONG-dev) — MagicTime base (old kernel track)
- [**kvsnr113**](https://github.com/kvsnr113) — E404 base and AnyKernel3 template for our installer
- [**osm0sis**](https://github.com/osm0sis) — AnyKernel3 (installer framework)
- [**kvsnr113**](https://github.com/kvsnr113) — SM8250 kernel base source (staging-bpf)
- [**rsuntk**](https://github.com/rsuntk) — KernelSU
- [**ZyCromerZ**](https://github.com/ZyCromerZ) — Clang toolchain
- [**ravindu644**](https://github.com/ravindu644) — author of DroidSpaces ([Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS)), the container infrastructure guiding the kernel choices

## ⚠️ Disclaimer

Custom kernel. **Use at your own risk** — always back up before flashing. Data
loss, bootloops or damage are not the project's responsibility.
