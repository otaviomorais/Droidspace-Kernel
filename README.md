# Droidspace Kernel

Custom kernel for **POCO F3 (alioth)** based on [MagicTime Kernel](https://github.com/TIMISONG-dev/kernel_xiaomi_sm8250) with full [DroidSpaces](https://github.com/nickcano/droidspaces) support.

## Features

- **MagicTime optimizations:** PELT, uclamp, thermal pressure, CASS scheduler, RCU boost/lazy, TEO CPU idle
- **KernelSu:** Built-in root support
- **DroidSpaces full support:** Namespaces, cgroups, overlayfs, veth, bridge, netfilter/NAT, seccomp
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
- [ravindu644](https://github.com/nickcano/droidspaces) - DroidSpaces kernel configs
- [ZyCromerZ](https://github.com/ZyCromerZ) - Clang toolchain
