# runzigc

A toy container runtime written in Zig.

## Prerequisites

CAUTION: Zig language is still under active development, so building with the latest zig release might fail.

- [zig v0.9.1](https://github.com/ziglang/zig/releases/tag/0.9.1)

## Build

### Debug build

```
zig build
```

`zig-out/bin/runzigc` is the built binary.

### Release build

```
zig build -Drelease-safe
```