const std = @import("std");
const iotest = @import("iotest");

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
