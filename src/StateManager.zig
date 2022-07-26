const StateManager = @This();

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
const OciSpec = @import("OciSpec.zig");

const state_file_name = "state.json";

pub const State = struct {
    /// Container ID
    id: []const u8,
    /// PID of init process
    init_process_pid: os.pid_t,
    init_process_start: u64,
    /// Created timestamp in ISO6801
    // TODO(musaprg): fix to marshal/unmarshal to zig's time object
    created: []const u8,
    // TODO(musaprg): add cgroup_paths
    // TODO(musaprg): add namespace_paths
};

const CgroupPaths = struct {
    blkio: []const u8,
    cpu: []const u8,
    cpuacct: []const u8,
    cpuset: []const u8,
    devices: []const u8,
    freezer: []const u8,
    hugetlb: []const u8,
    memory: []const u8,
    net_cls: []const u8,
    net_prio: []const u8,
    perf_event: []const u8,
    pids: []const u8,
    rdma: []const u8,
};

const NamespacePaths = struct {
    NEWCGROUP: []const u8,
    NEWIPC: []const u8,
    NEWNET: []const u8,
    NEWNS: []const u8,
    NEWUSER: []const u8,
    NEWUTS: []const u8,
};

allocator: Allocator,
parse_options: std.json.ParseOptions,
path: []const u8,

pub fn new(allocator: Allocator, root_path: []const u8) !StateManager {
    const options = std.json.ParseOptions{
        .allocator = allocator,
        // TODO(musaprg): change this to false finally to validate schema
        .ignore_unknown_fields = true,
        .allow_trailing_data = true,
    };
    const path = try fs.path.join(allocator, &[_][]const u8{ root_path, state_file_name });
    return StateManager{
        .allocator = allocator,
        .parse_options = options,
        .path = path,
    };
}

pub fn write(
    self: *const StateManager,
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
    self: *const StateManager,
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

pub fn deinit(self: *const StateManager, state: State) void {
    std.json.parseFree(State, state, self.parse_options);
}

// TODO(musaprg): write test
test "read" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const path = "./testdata";
    const container_state = try StateManager.new(allocator, path);
    const state = try container_state.read();
    try testing.expect(mem.eql(u8, "bd63ddfb3fda11986b6caa3a85aa6ac6a7def43e0d3298956e3891b91804a1af", state.id));
    try testing.expectEqual(@intCast(os.pid_t, 393), state.init_process_pid);
    try testing.expectEqual(@intCast(u64, 3164), state.init_process_start);
    try testing.expect(mem.eql(u8, "2022-09-18T06:36:31.3214015Z", state.created));
}
