const std = @import("std");
const engine = @import("engine.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var e: *engine.Engine = try engine.Engine.init(allocator);

    defer e.deinit();

    try e.run();
}
