const std = @import("std");

/// Runs a child process with the given arguments, sends the provided input to
/// its stdin, and captures its stdout, stderr and termination status.
pub fn runCmd(
    io: std.Io,
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    input: []const u8,
) !std.process.Child.RunResult {
    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    var out_buf: std.ArrayList(u8) = .empty;
    defer out_buf.deinit(allocator);
    var err_buf: std.ArrayList(u8) = .empty;
    defer err_buf.deinit(allocator);

    try child.spawn(io);
    errdefer {
        _ = child.kill(io) catch {};
    }

    if (child.stdin) |stdin| {
        defer {
            stdin.close(io);
            child.stdin = null;
        }
        // TODO: use buffering.
        try stdin.writeStreamingAll(io, input);
    }

    try child.collectOutput(allocator, &out_buf, &err_buf, 1024 * std.heap.page_size_min);
    return .{
        .stdout = try out_buf.toOwnedSlice(allocator),
        .stderr = try err_buf.toOwnedSlice(allocator),
        .term = try child.wait(io),
    };
}

test "runCmd" {
    const argv = &[_][]const u8{"cat"};
    const input = "This is a test.\n";

    const result = try runCmd(std.testing.io, std.testing.allocator, argv, input);
    defer std.testing.allocator.free(result.stdout);
    defer std.testing.allocator.free(result.stderr);

    try std.testing.expectEqualStrings(result.stdout, input);
    try std.testing.expectEqual(result.stderr.len, 0);
    try std.testing.expect(result.term == .Exited);
}
