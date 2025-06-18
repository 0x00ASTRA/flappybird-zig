const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const CallArgs = zlua.Lua.CallArgs;
const render = @import("renderer.zig");
const rl = @import("raylib");
const scripting = @import("scripting.zig");
const asset_manager = @import("asset_manager.zig");

pub const Engine = struct {
    allocator: std.mem.Allocator,
    scripting: *scripting.Scripting,
    renderer: *render.Renderer,
    asset_manager: *asset_manager.AssetManager,

    pub fn init(allocator: std.mem.Allocator) !*Engine {
        var engine = try allocator.create(Engine);

        engine.allocator = allocator;

        const r = try allocator.create(render.Renderer);
        r.* = try render.Renderer.init(allocator, "config/window.toml");
        engine.renderer = r;

        const am = try allocator.create(asset_manager.AssetManager);
        am.* = try asset_manager.AssetManager.init(allocator);
        engine.asset_manager = am;

        const s = try allocator.create(scripting.Scripting);
        s.* = try scripting.Scripting.init(allocator);
        engine.scripting = s;

        try engine.scripting.setupBindings(engine);

        engine.scripting.doFile("scripts/engine/init.lua") catch |err| {
            std.debug.print("Failed to load Lua File 'scripts/engine/init.lua' with error: {}", .{err});
        };

        engine.scripting.doFile("scripts/game/main.lua") catch |err| {
            std.debug.print("Failed to load Lua File 'scripts/game/main.lua' with error: {}", .{err});
        };

        return engine;
    }

    pub fn deinit(self: *Engine) void {
        self.scripting.deinit();
        self.allocator.destroy(self.scripting);

        self.asset_manager.deinit();
        self.allocator.destroy(self.asset_manager);

        self.renderer.deinit();
        self.allocator.destroy(self.renderer);

        self.allocator.destroy(self);
    }

    pub fn shouldClose(self: *Engine) bool {
        _ = self;
        return rl.windowShouldClose();
    } 

    pub fn run(self: *Engine) !void {
        // --- Attempt to get and call Lua's _init function ---
        const init_get_result = self.scripting.lua.getGlobal("_init");
        if (init_get_result) |init_value| {
            if (init_value == .function) {
                std.debug.print("\x1b[32m_init function found.\x1b[0m\n", .{});
                self.scripting.call(zlua.Lua.CallArgs{ .args = 0, .results = 0 });
                std.debug.print("Call __init()\n", .{});
            } else {
                self.scripting.lua.pop(1);
                std.debug.print("Warning: _init() global found but is not a function (type: {}). Skipping call.\n", .{init_value});
            }
        } else |err| {
            std.debug.print("Warning: Failed to retrieve Lua global '_init': {s}. Skipping call.\n", .{@errorName(err)});
        }

        // --- Main game loop ---
        while (!self.shouldClose()) {
            const update_get_result = self.scripting.lua.getGlobal("_update");
            if (update_get_result) |update_value| {
                if (update_value == .function) {
                    self.scripting.call(zlua.Lua.CallArgs{ .args = 0, .results = 0 }); // Call _update()
                } else {
                    self.scripting.lua.pop(1); // Pop the non-function value
                    std.debug.print("Warning: _update() global found but is not a function (type: {}). Game logic might not be updated.\n", .{update_value});
                }
            } else |err| {
                std.debug.print("Warning: Failed to retrieve Lua global '_update': {s}. Game logic might not be updated.\n", .{@errorName(err)});
            }

            const draw_get_result = self.scripting.lua.getGlobal("_draw");
            if (draw_get_result) |draw_value| {
                if (draw_value == .function) {
                    self.scripting.call(zlua.Lua.CallArgs{ .args = 0, .results = 0 }); // Call _draw()
                } else {
                    self.scripting.lua.pop(1); // Pop the non-function value
                    std.debug.print("Warning: _draw() global found but is not a function (type: {}). Nothing will be drawn.\n", .{draw_value});
                }
            } else |err| {
                std.debug.print("Warning: Failed to retrieve Lua global '_draw': {s}. Nothing will be drawn.\n", .{@errorName(err)});
            }

            self.renderer.present();
        }
    }
};
