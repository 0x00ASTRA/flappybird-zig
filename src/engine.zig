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
        while (!self.shouldClose()) {
            // try self.lua.call(.{ "update", .{} })

            self.renderer.draw(@constCast(&[_]render.Drawable{
                render.Drawable{ .circle = .{ .x = 400, .y = 400, .radius = 30.0, .color = .red } },
                render.Drawable{ .texture = .{ .texture = tex, .position = .{ .x = 0, .y = 0 }, .rotation = 0, .scale = 0.25, .tint = .white } },
            }));
            // try self.lua.call(.{ "render", .{} });
        }
    }

    // Hot-reload the Lua VM and re-use existing bindings
    pub fn reload(self: *Engine) !void {
        self.lua.deinit();
        const lua = try Lua.init(self.allocator);
        try lua.openLibs();
        try lua.doFile("scripts/engine/init.lua");
        self.lua = lua;

        inline for (self.bindings.items) |b| {
            try self.lua.setFn(b.name, b.func);
        }
    }
};
