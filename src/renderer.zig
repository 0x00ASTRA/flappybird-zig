// renderer.zig
const std = @import("std");
const rl = @import("raylib");
const toml = @import("toml");

pub const EWindowMode = enum { windowed, fullscreen, borderless };

pub const Drawable = union(enum) {
    circle: struct { x: i32, y: i32, radius: f32, color: rl.Color },
    rect: struct { x: i32, y: i32, width: i32, height: i32, color: rl.Color },
    text: struct { message: [:0]const u8, x: i32, y: i32, size: i32, color: rl.Color },
    texture: struct { texture: rl.Texture2D, position: rl.Vector2, rotation: f32, scale: f32, tint: rl.Color },
    fps: struct { x: i32, y: i32 },
};

pub const WindowConfig = struct {
    width: i32,
    height: i32,
    title: []const u8,
    mode: EWindowMode,
    target_fps: i32,
};

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    config: WindowConfig,
    title_cstr: [:0]const u8,
    // DESIGN FLAW FIX: Use a queue to batch draw calls for performance.
    // Instead of drawing one item at a time, we'll add them to this list.
    draw_queue: std.ArrayList(Drawable),

    pub fn init(allocator: std.mem.Allocator, cfg_filename: []const u8) !Renderer {
        var parser = toml.Parser(WindowConfig).init(allocator);
        defer parser.deinit();

        const cfg = try parser.parseFile(cfg_filename);
        const val = cfg.value;

        // Keep the duplicated string so we can free it later.
        const title_cstr = try allocator.dupeZ(u8, val.title);

        rl.initWindow(val.width, val.height, title_cstr);
        rl.setTargetFPS(val.target_fps);

        return Renderer{
            .allocator = allocator,
            .config = val,
            .title_cstr = title_cstr,
            // Initialize the draw queue.
            .draw_queue = std.ArrayList(Drawable).init(allocator),
        };
    }

    pub fn deinit(self: *Renderer) void {
        // Deinitialize the queue to free its memory.
        self.draw_queue.deinit();

        // MEMORY LEAK FIX: Free the title string we allocated in init.
        self.allocator.free(self.title_cstr);

        rl.closeWindow();
    }

    /// Renamed from `draw` to `queue` to better reflect its purpose.
    /// This function now quickly adds a drawable item to a list for later processing.
    pub fn queue(self: *Renderer, drawable: Drawable) !void {
        try self.draw_queue.append(drawable);
    }

    /// This new function performs all the drawing for the frame at once.
    /// It should be called once per frame in your main game loop.
    pub fn present(self: *Renderer) void {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);

        // Process all the items that were queued this frame.
        for (self.draw_queue.items) |item| {
            switch (item) {
                .circle => |c| {
                    rl.drawCircle(c.x, c.y, c.radius, c.color);
                },
                .rect => |r| {
                    rl.drawRectangle(r.x, r.y, r.width, r.height, r.color);
                },
                .text => |t| {
                    rl.drawText(t.message, t.x, t.y, t.size, t.color);
                },
                .texture => |t| {
                    // DESIGN FLAW FIX: Use floating point math for the origin offset
                    // to ensure smooth scaling and rotation.
                    const origin = rl.Vector2{
                        .x = (@as(f32, @floatFromInt(t.texture.width)) * t.scale) / 2.0,
                        .y = (@as(f32, @floatFromInt(t.texture.height)) * t.scale) / 2.0,
                    };
                    const dest_rect = rl.Rectangle{
                        .x = t.position.x,
                        .y = t.position.y,
                        .width = @as(f32, @floatFromInt(t.texture.width)) * t.scale,
                        .height = @as(f32, @floatFromInt(t.texture.height)) * t.scale,
                    };
                    rl.drawTexturePro(t.texture, dest_rect, origin, t.rotation, t.tint);
                },
                .fps => |f| {
                    rl.drawFPS(f.x, f.y);
                },
            }
        }

        // Clear the queue to be ready for the next frame.
        self.draw_queue.clearRetainingCapacity();
    }
};
