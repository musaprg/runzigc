# runzigc

A toy container runtime written in Zig

## Prerequisities

- zigmod
    - zig v0.9.1, you need to use v93. https://github.com/nektro/zigmod/releases/download/v93/zigmod-x86_64-linux

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