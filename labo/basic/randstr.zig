const std = @import("std");

// https://github.com/vrischmann/zig-prometheus/blob/46c6a1d32802976e84659dfedaaee70408850091/examples/basic/main.zig
fn getRandomString(allocator: std.mem.Allocator, random: std.rand.Random, n: usize) ![]const u8 {
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
    var prng = std.rand.DefaultPrng.init(@intCast(u64, now));
    const random = prng.random();
    // i don't know how to iterate in specific counts
    for ([_]u0{0} ** 3) |_, i| {
        _ = i;
        const hoge = getRandomString(allocator, random, 10);
        std.debug.print("{s}\n", .{hoge});
    }
}
