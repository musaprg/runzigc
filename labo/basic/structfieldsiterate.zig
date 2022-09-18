const std = @import("std");

// https://gist.github.com/travisstaloch/71a7a2bc260997abe06016c619b40bf2
pub fn main() !void {
    const U1s = packed struct {
        a: u1,
        b: u1,
        c: u1,
    };

    const x = U1s{ .a = 1, .b = 0, .c = 0 };
    inline for (std.meta.fields(@TypeOf(x))) |f| {
        std.debug.print(f.name ++ " {}\n", .{@as(f.field_type, @field(x, f.name))});
    }
}
