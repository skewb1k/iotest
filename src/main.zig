const std = @import("std");
const iotest = @import("iotest");
const parseCmd = @import("parse_cmd.zig").parseCmd;
const runCmd = @import("run_cmd.zig").runCmd;

pub fn main() !void {
    // TODO: consider using arena.
    var gpa_instance: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = gpa_instance.allocator();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len != 3) {
        fatalUsage("expected 2 arguments, found {d}", .{args.len - 1});
    }
    const tests_path = args[1];
    const cmd = args[2];

    const tests_bytes = std.fs.cwd().readFileAlloc(gpa, tests_path, 16 * 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => fatal("file not found: {s}", .{tests_path}),
        else => fatal("error reading file {s}: {any}", .{ tests_path, err }),
    };
    defer gpa.free(tests_bytes);

    const tests = try iotest.parseIOTests(gpa, tests_bytes);
    defer gpa.free(tests);

    const argv = try parseCmd(gpa, cmd);

    var out_buf: [1024]u8 = undefined;
    var out_w = std.fs.File.stdout().writer(&out_buf);
    const out = &out_w.interface;

    var failed: bool = false;
    for (tests, 1..) |t, t_num| {
        const result = runCmd(gpa, argv, t.input) catch |err| switch (err) {
            error.FileNotFound => fatal("failed to run '{s}': no such file or directory", .{cmd}),
            else => fatal("error running {s}: {any}", .{ cmd, err }),
        };
        const got = result.stdout;
        if (!std.mem.eql(u8, got, t.output)) {
            failed = true;
            try printFailedTest(out, t_num, t, got);
        }
    }
    if (failed) {
        std.process.exit(1);
    }
}

fn printFailedTest(
    w: *std.Io.Writer,
    t_num: usize,
    t: iotest.IOTest,
    got: []const u8,
) !void {
    try w.print("=== Test {d} failed ===\n", .{t_num});
    try w.print("Input:\n{s}", .{t.input});
    try w.print("Expected:\n{s}", .{t.output});
    try w.print("Got:\n{s}", .{got});
    try w.flush();
}

fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print("iotest: " ++ fmt ++ "\n", args);
    std.process.exit(1);
}

fn fatalUsage(comptime fmt: []const u8, args: anytype) noreturn {
    fatal(fmt ++ "\nusage: iotest <path> <command>", args);
}

test {
    _ = @import("parse_cmd.zig");
    _ = @import("run_cmd.zig");
}
