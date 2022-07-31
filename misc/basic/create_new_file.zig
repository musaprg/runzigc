const std = @import("std");
const fs = std.fs;
const testing = std.testing;
const ArenaAllocator = std.heap.ArenaAllocator;
const print = std.debug.print;

pub fn main() !void {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // https://github.com/ziglang/zig/blob/6d44a6222d6eba600deb7f16c124bfa30628fb60/lib/std/fs/test.zig#L1031
    const base_path = blk: { // I don't know why this is needed
        const relative_path = try fs.path.join(allocator, &[_][]const u8{"."});
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    const message = "Hello, world!\n";
    // if you want to create another subdir, use fs.path.join
    // `var subdir_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "hoge" });`
    fs.makeDirAbsolute(base_path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
    try fs.accessAbsolute(base_path, .{});
    var subdir = try fs.openDirAbsolute(base_path, .{});
    subdir.writeFile("test.txt", message) catch |err| switch (err) {
        else => return err,
    };
}
