const CgroupsManager = @This();

const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const meta = std.meta;
const fmt = std.fmt;
const fs = std.fs;
const os = std.os;
const Allocator = mem.Allocator;

const util = @import("util.zig");

const cgroup_procs_file_name = "cgroups.procs";

// Currently, runzigc only supports cgroup v1.

// TODO(musaprg): refactor this file more generic, avoid dirty implementation

const CgroupPaths = struct {
    // TODO(musaprg): enable all subsystem
    // blkio: []const u8 = "",
    cpu: []const u8,
    cpuacct: []const u8,
    // cpuset: []const u8,
    devices: []const u8,
    freezer: []const u8,
    // hugetlb: []const u8,
    memory: []const u8,
    // net_cls: []const u8,
    // net_prio: []const u8,
    // perf_event: []const u8,
    //pids: []const u8,
    //rdma: []const u8,
};

allocator: Allocator,
cgroup_paths: CgroupPaths,

pub fn new(allocator: Allocator, container_id: []const u8) !CgroupsManager {
    return CgroupsManager{
        .allocator = allocator,
        // TODO(musaprg): Cgroup v2
        .cgroup_paths = CgroupPaths{
            // TODO(musaprg): enable all subsystem
            .blkio = try generate_cgroups_path(allocator, "blkio", container_id),
            .cpu = try generate_cgroups_path(allocator, "cpu", container_id),
            .cpuacct = try generate_cgroups_path(allocator, "cpuacct", container_id),
            //.cpuset = try generate_cgroups_path(allocator, "cpuset", container_id),
            .devices = try generate_cgroups_path(allocator, "devices", container_id),
            .freezer = try generate_cgroups_path(allocator, "freezer", container_id),
            //.hugetlb = try generate_cgroups_path(allocator, "hugetlb", container_id),
            .memory = try generate_cgroups_path(allocator, "memory", container_id),
            // .net_cls = try generate_cgroups_path(allocator, "net_cls", container_id),
            // .net_prio = try generate_cgroups_path(allocator, "net_prio", container_id),
            // .perf_event = try generate_cgroups_path(allocator, "perf_event", container_id),
            // .pids = try generate_cgroups_path(allocator, "pids", container_id),
            // .rdma = try generate_cgroups_path(allocator, "rdma", container_id),
        },
    };
}

pub fn join(self: *CgroupsManager, pid: os.pid_t) !void {
    inline for (std.meta.fields(@TypeOf(self.cgroup_paths))) |f| {
        var subsystem_path = @as(f.field_type, @field(x, f.name));
        try util.mkdirAll(subsystem_path, 0o755);
        const cgroup_procs_path = try fs.path.join(self.allocator, &[_][]const u8{ subsystem_path, cgroup_procs_file_name });
        const cgroup_procs = try fs.cwd().openFile(cgroup_cpu_tasks_path, .{ .write = true });
        defer cgroup_procs.close();
        const cgroup_procs_content = try fmt.allocPrint(allocator, "{}\n", .{pid});
        defer allocator.free(cgroup_procs_content);
        try cgroup_procs.writer().writeAll(cgroup_procs_content);
    }
}

// Do freeze with freezer subsystem
pub fn freeze(self: *CgroupsManager) !void {
    // FIXME(musaprg): Implement me
}

// Remove cgroup subsystem resource
pub fn destroy(self: *CgroupsManager) !void {
    // TODO(musaprg): backoff retry
    // FIXME(musaprg): Implement me
}

pub fn deinit(self: *CgroupsManager) void {
    // TODO(musaprg): consider more clever way
    // TODO(musaprg): enable all subsystem
    // self.allocator.free(self.cgroup_paths.blkio);
    self.allocator.free(self.cgroup_paths.cpu);
    self.allocator.free(self.cgroup_paths.cpuacct);
    //self.allocator.free(self.cgroup_paths.cpuset);
    self.allocator.free(self.cgroup_paths.devices);
    self.allocator.free(self.cgroup_paths.freezer);
    // self.allocator.free(self.cgroup_paths.hugetlb);
    self.allocator.free(self.cgroup_paths.memory);
    // self.allocator.free(self.cgroup_paths.net_cls);
    // self.allocator.free(self.cgroup_paths.net_prio);
    // self.allocator.free(self.cgroup_paths.perf_event);
    // self.allocator.free(self.cgroup_paths.pids);
    // self.allocator.free(self.cgroup_paths.rdma);
}

fn generate_cgroups_path(allocator: Allocator, name: []const u8, container_id: []const u8) ![]const u8 {
    return try fs.path.join(allocator, &[_][]const u8{ "/sys/fs/cgroup", name, "runzigc", container_id });
}

test "new" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const cgroups_manager = try CgroupsManager.new(allocator, "hoge");
    try testing.expect(mem.eql(u8, "/sys/fs/cgroup/blkio/runzigc/hoge", cgroups_manager.cgroup_paths.blkio));
    // TODO(musaprg): write for each field case
}
