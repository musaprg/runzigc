const OciSpec = @This();

const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const meta = std.meta;
const Allocator = mem.Allocator;

pub const RuntimeSpec = struct {
    ociVersion: []const u8,
    root: Root,
    mounts: []Mount = &[_]Mount{},
    // TODO(musaprg): implement POSIX-platform hooks https://github.com/opencontainers/runtime-spec/blob/main/config.md#posix-platform-hooks
    linux: Linux,
};

// TODO(musaprg): take care about optional
const Root = struct {
    path: []const u8,
    readonly: bool,
};

const Mount = struct {
    destination: []const u8,
    source: []const u8,
    options: []const []const u8 = &[_][]const u8{},
    type: []const u8,
};

const Linux = struct {
    namespaces: []Namespace,
    uidMappings: []UidMapping,
    devices: []Device,
    cgroupsPath: []const u8,
};

const Namespace = struct {
    type: []const u8,
    path: ?[]const u8 = null,
};

const UidMapping = struct {
    containerID: u32,
    hostID: u32,
    size: u32,
};

const Device = struct {
    type: []const u8,
    path: []const u8,
    major: i64,
    minor: i64,
    fileMode: u32,
    uid: u32,
    gid: u32,
};

const CgroupResource = struct {
    cpu: Cpu,
    memory: Memory,
    devices: []AllowedDevice,
};

const Cpu = struct {
    shares: u64,
    quota: i64,
    period: i64,
    realtimeRuntime: i64,
    realtimePeriod: i64,
    cpus: []const u8,
    mems: []const u8,
    idle: i64,
};

const Memory = struct {
    limit: i64,
    reservation: i64,
    swap: i64,
    kernel: i64,
    kernelTCP: i64,
};

const AllowedDevice = struct {
    allow: bool,
    type: []const u8,
    major: i64,
    minor: i64,
    access: []const u8,
};

const BlockIo = struct {
    weight: u16,
    leafWeight: u16,
    weightDevice: []WeightDevice,
    throttleReadBpsDevice: []DeviceRateLimit,
    throttleWriteBpsDevice: []DeviceRateLimit,
    throttleReadIOPSDevice: []DeviceRateLimit,
    throttleWriteIOPSDevice: []DeviceRateLimit,
};

const WeightDevice = struct {
    major: i64,
    minor: i64,
    weight: u16,
    leafWeight: u16,
};

const DeviceRateLimit = struct {
    major: i64,
    minor: i64,
    rate: u64,
};

const HugepageLimit = struct {
    pageSize: []const u8,
    limit: u64,
};

const Network = struct {
    classID: u32,
    priorities: []NetworkPriority,
};

const NetworkPriority = struct {
    name: []const u8,
    priority: u32,
};

allocator: Allocator,
parse_options: std.json.ParseOptions,
spec: RuntimeSpec,

pub fn new(allocator: Allocator, path: []const u8) !OciSpec {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const file_size = try file.getEndPos();
    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();
    const contents = try istream.readAllAlloc(allocator, file_size);
    defer allocator.free(contents);

    const options = std.json.ParseOptions{
        .allocator = allocator,
        // TODO(musaprg): change this to false finally to validate schema
        .ignore_unknown_fields = true,
        .allow_trailing_data = true,
    };

    // TODO(musaprg): separate RuntimeSpec definition from this file.
    const spec = try std.json.parse(RuntimeSpec, &std.json.TokenStream.init(contents), options);
    return OciSpec{
        .allocator = allocator,
        .spec = spec,
        .parse_options = options,
    };
}

pub fn deinit(self: *OciSpec) void {
    std.json.parseFree(RuntimeSpec, self.spec, self.parse_options);
}

test "sample spec for linux" {
    const allocator = testing.allocator;
    var config = try OciSpec.new(allocator, "./testdata/sample_spec_linux.json");
    var spec = config.spec;
    defer config.deinit();
    // TODO(musaprg): implement direct struct comparison
    try testing.expect(mem.eql(u8, spec.ociVersion, "1.0.1"));
    try testing.expect(mem.eql(u8, spec.root.path, "rootfs"));
    try testing.expectEqual(spec.root.readonly, true);
    // TODO(musaprg): check mounts' contents
    try testing.expectEqual(spec.mounts.len, 7);
}
