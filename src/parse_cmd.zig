const std = @import("std");

/// Splits a command string into arguments, returning an owned slice of strings.
pub fn parseCmd(allocator: std.mem.Allocator, cmd: []const u8) ![]const []const u8 {
    var args: std.ArrayList([]const u8) = .empty;
    defer args.deinit(allocator);

    var it = std.mem.tokenizeAny(u8, cmd, " \t\n");
    while (it.next()) |arg| {
        try args.append(allocator, arg);
    }

    return args.toOwnedSlice(allocator);
}

test "parseCmd" {
    {
        const cmd = try parseCmd(std.testing.allocator, "");
        defer std.testing.allocator.free(cmd);
        try std.testing.expectEqualDeep(&[_][]const u8{}, cmd);
    }
    {
        const cmd = try parseCmd(std.testing.allocator, "cat");
        defer std.testing.allocator.free(cmd);
        try std.testing.expectEqualDeep(&[_][]const u8{"cat"}, cmd);
    }
    {
        const cmd = try parseCmd(std.testing.allocator, "cat -n file.txt");
        defer std.testing.allocator.free(cmd);
        try std.testing.expectEqualDeep(&[_][]const u8{ "cat", "-n", "file.txt" }, cmd);
    }
}
