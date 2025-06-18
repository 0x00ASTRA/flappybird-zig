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
    draw_queue: std.ArrayList(Drawable),

    pub fn init(allocator: std.mem.Allocator, cfg_filename: []const u8) !Renderer {
        var parser = toml.Parser(WindowConfig).init(allocator);
        defer parser.deinit();

        const cfg = try parser.parseFile(cfg_filename);
        const val = cfg.value;

        const title_cstr = try allocator.dupeZ(u8, val.title);

        rl.initWindow(val.width, val.height, title_cstr);
        rl.setTargetFPS(val.target_fps);

        return Renderer{
            .allocator = allocator,
            .config = val,
            .title_cstr = title_cstr,
            .draw_queue = std.ArrayList(Drawable).init(allocator),
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.draw_queue.deinit();

        self.allocator.free(self.title_cstr);

        rl.closeWindow();
    }

    /// This function adds a drawable item to a list for later processing.
    pub fn queue(self: *Renderer, drawable: Drawable) !void {
        try self.draw_queue.append(drawable);
    }

    pub fn get_frame_time(self: *@This()) f32 {
        _ = self;
        return rl.getFrameTime();
    }

    /// This function performs all the drawing for the frame at once.
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
                    // const center_pos: rl.Vector2 = rl.Vector2{ .x = t.position.x - (@as(f32, @floatFromInt(@divFloor(t.texture.width, 2))) * t.scale), .y = t.position.y - (@as(f32, @floatFromInt(@divFloor(t.texture.width, 2))) * t.scale) };
                    rl.drawTextureEx(t.texture, rl.Vector2.init(t.position.x, t.position.y), t.rotation, t.scale, t.tint);
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
