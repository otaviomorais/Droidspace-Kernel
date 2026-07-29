# DroidSpace Kernel

Custom kernel for **POCO F3 (alioth)** based on [MagicTime Kernel](https://github.com/TIMISONG-dev/kernel_xiaomi_sm8250) with full [DroidSpaces](https://github.com/ravindu644/Droidspaces-OSS) support, unified cgroup v2, and `DroidSpace` local version suffix (`uname -r` reports `…-DroidSpace`).

## Features

- **MagicTime optimizations:** PELT, uclamp, thermal pressure, CASS scheduler, RCU boost/lazy, TEO CPU idle
- **KernelSU-Next:** Built-in root support (v3.2.0-legacy)
- **DroidSpaces full support:** Namespaces, cgroups, overlayfs, veth, bridge, netfilter/NAT, seccomp
- **Unified cgroup v2:** `CONFIG_CGROUP2=y` + `cgroup_no_v1=all` — single hierarchy for systemd / lmkd / containers
- **ZRAM:** LZ4 compression
- **Networking:** Westwood TCP congestion, advanced netfilter

## Building

Build is automated via GitHub Actions. Trigger a workflow dispatch from the Actions tab.

To build locally:
```bash
./build.sh
```

## Credits

- [TIMISONG-dev](https://github.com/TIMISONG-dev) - MagicTime Kernel
- [ravindu644](https://github.com/ravindu644) - DroidSpaces kernel configs ([Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS))
- [ZyCromerZ](https://github.com/ZyCromerZ) - Clang toolchain
- [LineageOS](https://github.com/LineageOS) - GCC toolchains
- [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) - KernelSU
