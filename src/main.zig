const std = @import("std");
const iotest = @import("iotest");
const parseCmd = @import("parse_cmd.zig").parseCmd;
const runCmd = @import("run_cmd.zig").runCmd;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn main() !void {
    // TODO: consider using arena.
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 3) {
        std.process.fatal("Usage: iotest <path> <command>", .{});
    }
    const file_path = args[1];
    const cmd = args[2];

    const content = std.fs.cwd().readFileAlloc(allocator, file_path, 16 * 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => std.process.fatal("file not found: {s}", .{file_path}),
        else => std.process.fatal("reading file {s}: {any}", .{ file_path, err }),
    };
    defer allocator.free(content);

    const tests = try iotest.parseIOTests(allocator, content);
    defer allocator.free(tests);

    const argv = try parseCmd(allocator, cmd);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var failed: bool = false;
    for (tests, 1..) |t, t_num| {
        const result = runCmd(allocator, argv, t.input) catch |err| switch (err) {
            error.FileNotFound => std.process.fatal("{s}: no such file or directory", .{cmd}),
            else => std.process.fatal("running {s}: {any}", .{ cmd, err }),
        };
        const got = result.stdout;
        if (!std.mem.eql(u8, got, t.output)) {
            failed = true;
            try printFailedTest(stdout, t_num, t, got);
        }
    }
    if (failed) {
        std.process.exit(1);
    }
}

pub fn printFailedTest(
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

test {
    _ = @import("parse_cmd.zig");
    _ = @import("run_cmd.zig");
}
