const std = @import("std");

/// Represents a single input/output test case.
pub const IOTest = struct {
    /// Input data to be fed to the program.
    input: []const u8,
    /// Expected output data from the program.
    output: []const u8,
};

/// Parses a string containing multiple IO test blocks into an owned slice of `IOTest`.
///
/// Each block is separated by `"===\n"` and contains an input/output pair
/// separated by `"---\n"`. Returns `error.InvalidFormat` if the input is incorrect.
pub fn parseIOTests(allocator: std.mem.Allocator, s: []const u8) ![]IOTest {
    var res: std.ArrayList(IOTest) = .empty;
    defer res.deinit(allocator);

    var block_iter = std.mem.splitSequence(u8, s, "===\n");
    while (block_iter.next()) |block| {
        var io_iter = std.mem.splitSequence(u8, block, "---\n");
        const input = io_iter.next() orelse return error.InvalidFormat;
        const output = io_iter.next() orelse return error.InvalidFormat;
        try res.append(allocator, .{
            .input = input,
            .output = output,
        });
    }
    return res.toOwnedSlice(allocator);
}

fn testParseIOTests(expected: []const IOTest, input: []const u8) !void {
    const allocator = std.testing.allocator;

    const actual = try parseIOTests(allocator, input);
    defer allocator.free(actual);

    try expectEqualIOTests(expected, actual);
}

fn expectEqualIOTests(expected: []const IOTest, actual: []const IOTest) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, 0..) |e, i| {
        const a = actual[i];
        try std.testing.expectEqualStrings(e.input, a.input);
        try std.testing.expectEqualStrings(e.output, a.output);
    }
}

test "parseIOTests" {
    try testParseIOTests(&[_]IOTest{
        .{ .input = "", .output = "" },
    },
        \\---
        \\
    );
    try testParseIOTests(&[_]IOTest{
        .{ .input = "\n", .output = "\n" },
    },
        \\
        \\---
        \\
        \\
    );
    try testParseIOTests(&[_]IOTest{
        .{ .input = "input1\n", .output = "output1\n" },
    },
        \\input1
        \\---
        \\output1
        \\
    );
    try testParseIOTests(&[_]IOTest{
        .{ .input = "line1\n\nline2\n", .output = "lline1\nlline2\n" },
    },
        \\line1
        \\
        \\line2
        \\---
        \\lline1
        \\lline2
        \\
    );
    try testParseIOTests(&[_]IOTest{
        .{ .input = "input1\n", .output = "output1\n" },
        .{ .input = "input2\n", .output = "output2\n" },
        .{ .input = "input3\n", .output = "output3\n" },
    },
        \\input1
        \\---
        \\output1
        \\===
        \\input2
        \\---
        \\output2
        \\===
        \\input3
        \\---
        \\output3
        \\
    );
}
