const ContainerState = @This();

// subset of libcontainer's state
// ref(BaseState): https://github.com/opencontainers/runc/blob/v1.1.4/libcontainer/container.go
// ref(linux-specific State): https://github.com/opencontainers/runc/blob/5fd4c4d144137e991c4acebb2146ab1483a97925/libcontainer/container_linux.go#L58-L85

const std = @import("std");
const os = std.os;
const testing = std.testing;
const mem = std.mem;
const meta = std.meta;
const fs = std.fs;
const Allocator = mem.Allocator;

const util = @import("util.zig");
const ocispec = @import("ocispec.zig");

const state_file_name = "state.json";

const State = struct {
    /// Container ID
    id: []const u8,
    /// PID of init process
    init_process_pid: i64,
    init_process_start: u64,
    /// Created timestamp
    created: i64,
    /// Container configuration in OCI spec format
    config: ocispec.RuntimeSpec,
};

allocator: Allocator,
parse_options: std.json.ParseOptions,
path: []const u8,

pub fn new(allocator: Allocator, root_path: []const u8) !ContainerState {
    const options = std.json.ParseOptions{
        .allocator = allocator,
        // TODO(musaprg): change this to false finally to validate schema
        .ignore_unknown_fields = true,
        .allow_trailing_data = true,
    };
    const path = try fs.path.join(allocator, &[_][]const u8{ root_path, state_file_name });
    return ContainerState{
        .allocator = allocator,
        .parse_options = options,
        .path = path,
    };
}

pub fn write(
    self: *const ContainerState,
    state: State,
) !void {
    const path = try util.createTempFile(self.allocator, "");
    defer self.allocator.free(path);
    const state_file = try fs.openFileAbsolute(path, .{ .write = true });
    defer state_file.close();
    try std.json.stringify(state, .{}, state_file.writer());
    try fs.renameAbsolute(path, self.path);
}

pub fn read(
    self: *const ContainerState,
) !State {
    const file = try std.fs.cwd().openFile(self.path, .{});
    defer file.close();
    const file_size = try file.getEndPos();
    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();
    const contents = try istream.readAllAlloc(self.allocator, file_size);
    defer self.allocator.free(contents);

    const state = try std.json.parse(State, &std.json.TokenStream.init(contents), self.parse_options);
    return state;
}

pub fn deinit(self: *const ContainerState, state: State) void {
    std.json.parseFree(State, state, self.parse_options);
}

// TODO(musaprg): write test
