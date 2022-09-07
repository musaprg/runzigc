# runzigc

A toy container runtime written in Zig.

## Prerequisites

CAUTION: Zig language is still under active development, so building with the latest zig release might fail.

- [zig v0.9.1](https://github.com/ziglang/zig/releases/tag/0.9.1)

## Build

Before build, you need to fetch submodules.

```
$ git submodule update --init --recursive
```

### Debug build

```
zig build
```

`zig-out/bin/runzigc` is the built binary.

### Release build

```
zig build -Drelease-safe
```

## Similar projects

- [fancl20/zrun](https://github.com/fancl20/zrun) A fast and low-memory footprint (non-standard) container runtime fully written in Zig.
- [containers/youki](https://github.com/containers/youki) A container runtime written in Rust
