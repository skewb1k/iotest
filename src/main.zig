const std = @import("std");
const iotest = @import("iotest");
const parseCmd = @import("parse_cmd.zig").parseCmd;
const runCmd = @import("run_cmd.zig").runCmd;

pub fn main(init: std.process.Init) !void {
    // TODO: consider using arena.
    const gpa = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len != 3) {
        fatalWithUsage("expected 2 arguments, found {d}", .{args.len - 1});
    }
    const tests_path = args[1];
    const cmd = args[2];

    const cwd: std.Io.Dir = .cwd();
    const tests_bytes = cwd.readFileAlloc(io, tests_path, gpa, .unlimited) catch |err| switch (err) {
        error.FileNotFound => fatal("file not found: {s}", .{tests_path}),
        else => fatal("error reading file {s}: {any}", .{ tests_path, err }),
    };
    defer gpa.free(tests_bytes);

    const tests = try iotest.parseIOTests(gpa, tests_bytes);
    defer gpa.free(tests);

    const argv = try parseCmd(gpa, cmd);

    var stdout_buffer: [std.heap.page_size_min]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var failed = false;
    for (tests, 1..) |t, t_num| {
        const result = runCmd(io, gpa, argv, t.input) catch |err| switch (err) {
            error.FileNotFound => fatal("failed to run '{s}': no such file or directory", .{cmd}),
            else => fatal("error running {s}: {any}", .{ cmd, err }),
        };
        const got = result.stdout;
        if (!std.mem.eql(u8, got, t.output)) {
            failed = true;
            try printFailedTest(stdout, t_num, t, got);
        }
        if (result.stderr.len > 0) {
            failed = true;
            try stdout.print("Unexpected stderr output:\n{s}", .{result.stderr});
        }
        try stdout.flush();
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
}

fn fatalWithUsage(comptime fmt: []const u8, args: anytype) noreturn {
    fatal(fmt ++ "\nusage: iotest <path> <command>", args);
}

fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print("iotest: " ++ fmt ++ "\n", args);
    std.process.exit(1);
}

test {
    _ = @import("parse_cmd.zig");
    _ = @import("run_cmd.zig");
}
