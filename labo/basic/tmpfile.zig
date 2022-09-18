const std = @import("std");
const rand = std.rand;
const fs = std.fs;
const mem = std.mem;
const Allocator = mem.Allocator;

pub const RandomStringError = mem.Allocator.Error;

/// Generate random string
pub fn randomString(allocator: Allocator, random: rand.Random, n: usize) RandomStringError![]const u8 {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    var items = try allocator.alloc(u8, n);
    for (items) |*item| {
        const random_pos = random.intRangeLessThan(usize, 0, chars.len);
        item.* = chars[random_pos];
    }

    return items;
}

pub fn main() !void {
    const now = std.time.timestamp();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    const parent_path = "/tmp";
    var prng = rand.DefaultPrng.init(@intCast(u64, now));
    const random = prng.random();
    const max_retry = 10;
    const length = 10;
    for ([_]u0{0} ** max_retry) |_| {
        const file_name = try randomString(allocator, random, length);
        std.debug.print("createTempFile: try to create '{s}'", .{file_name});
        const path = try fs.path.join(allocator, &[_][]const u8{ parent_path, file_name });
        const file = fs.createFileAbsolute(path, .{}) catch |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err,
        };
        defer file.close();
        return std.debug.print("{s}\n", .{path});
    }
}
