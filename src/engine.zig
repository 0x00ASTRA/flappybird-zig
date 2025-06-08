const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const render = @import("renderer.zig");
const rl = @import("raylib");

pub fn ping(lua: *Lua) c_int {
    _ = lua;
    std.debug.print("\x1b[32mpong\x1b[0m\n", .{});
    return 0;
}

pub fn log(lua: *Lua) c_int {
    var msg: [:0]const u8 = undefined;
    msg = lua.toString(-1) catch unreachable;
    std.debug.print("\x1b[34m[Debug]::Log: '{s}'\x1b[0m\n", .{msg});
    return 0;
}

pub const Engine = struct {
    allocator: std.mem.Allocator,
    lua: *Lua,
    renderer: *render.Renderer,
    textures: std.StringHashMap(rl.Texture2D),

    pub fn init(allocator: std.mem.Allocator) !*Engine {
        var lua = try Lua.init(allocator);
        _ = lua.openLibs();
        try lua.doFile("scripts/engine/init.lua");

        const r = try allocator.create(render.Renderer);
        r.* = try render.Renderer.init(allocator, "config/window.toml");

        var en = try allocator.create(Engine);
        en.* = Engine{
            .allocator = allocator,
            .lua = lua,
            .renderer = r,
            .textures = std.StringHashMap(rl.Texture2D).init(allocator),
        };

        var textures_dir = try std.fs.cwd().openDir("assets/textures/", .{ .iterate = true });
        defer textures_dir.close();

        var iter = textures_dir.iterate();
        while (try iter.next()) |f| {
            if (f.kind == .file) {
                const full_path_str = try std.fmt.allocPrintZ(allocator, "assets/textures/{s}", .{f.name});
                defer allocator.free(full_path_str);

                const texture = blk: {
                    if (rl.loadTexture(full_path_str)) |loaded_texture| {
                        break :blk loaded_texture;
                    } else |err| {
                        std.debug.print("Failed to load texture: {s} with error '{s}'\n", .{ f.name, @errorName(err) });

                        // Allocate memory for the error message string
                        const error_msg_buf = try std.fmt.allocPrintZ(allocator, "ERROR: {s}", .{f.name});
                        defer allocator.free(error_msg_buf); // Ensure it's freed

                        const error_image = rl.genImageText(20, 20, error_msg_buf);
                        defer rl.unloadImage(error_image); // Unload the generated image data

                        // loadTextureFromImage returns a Texture2D, so we can use it directly
                        break :blk try rl.loadTextureFromImage(error_image);
                    }
                };
                try en.textures.put(f.name, texture);
                std.debug.print("Loaded Texture: {s}\n", .{f.name});
            }
        }

        en.setupBindings();
        try en.lua.doFile("test/test.lua");
        return en;
    }
    pub fn deinit(self: *Engine) void {
        self.lua.deinit();
        self.renderer.deinit();
        self.allocator.destroy(self.renderer);
        self.allocator.destroy(self);
    }

    pub fn setupBindings(self: *Engine) void {
        self.lua.pushFunction(zlua.wrap(ping));
        self.lua.setGlobal("ping");

        self.lua.pushFunction(zlua.wrap(log));
        self.lua.setGlobal("log");
    }

    pub fn shouldClose(self: *Engine) bool {
        _ = self;
        return rl.windowShouldClose();
    }

    pub fn run(self: *Engine) !void {
        const tx = self.textures.get("test.png").?;
        const tex = tx;
        var tick: u64 = 0;
        // var rot_rate: f32 = 3; // 3 degrees per sec
        var pos_x: i32 = 400;
        var pos_y: i32 = 400;
        var speed: i32 = 20;

        while (!self.shouldClose()) {

            // #######################################
            // #               Input                 #
            // #######################################

            if (rl.isKeyPressed(.left_shift)) {
                const new_speed = speed + 1;
                speed = std.math.clamp(new_speed, 0, 500);
            }

            if (rl.isKeyPressed(.left_control)) {
                const new_speed = speed - 1;
                speed = std.math.clamp(new_speed, 0, 500);
            }

            if (rl.isKeyDown(.down)) {
                const new_pos_y = pos_y + speed;
                pos_y = std.math.clamp(new_pos_y, 30, 770);
            }

            if (rl.isKeyDown(.up)) {
                const new_pos_y = pos_y - speed;
                pos_y = std.math.clamp(new_pos_y, 30, 770);
            }

            if (rl.isKeyDown(.right)) {
                const new_pos_x = pos_x + speed;
                pos_x = std.math.clamp(new_pos_x, 30, 770);
            }

            if (rl.isKeyDown(.left)) {
                const new_pos_x = pos_x - speed;
                pos_x = std.math.clamp(new_pos_x, 30, 770);
            }

            const tick_msg: [:0]const u8 = std.fmt.allocPrintZ(self.allocator, "tick: {}", .{tick}) catch "error";
            self.renderer.draw(@constCast(&[_]render.Drawable{
                render.Drawable{ .texture = .{ .texture = tex, .position = .{ .x = 400, .y = 400 }, .rotation = 0, .scale = 0.5, .tint = .white } },
                render.Drawable{ .circle = .{ .x = pos_x, .y = pos_y, .radius = 30.0, .color = .red } },
                render.Drawable{ .text = .{ .message = tick_msg, .x = 5, .y = 5, .size = 11, .color = .red } },
                render.Drawable{ .fps = .{ .x = 5, .y = 17 } },
            }));
            tick += 1;
        }
    }
};
