const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const CallArgs = zlua.Lua.CallArgs;
const render = @import("renderer.zig");
const rl = @import("raylib");
const scripting = @import("scripting.zig"); // New Import
const asset_manager = @import("asset_manager.zig"); // New Import

pub const Engine = struct {
    allocator: std.mem.Allocator,
    scripting: *scripting.Scripting, // Now holds a pointer to Scripting
    renderer: *render.Renderer,
    asset_manager: *asset_manager.AssetManager, // Now holds a pointer to AssetManager

    pub fn init(allocator: std.mem.Allocator) !*Engine {
        var engine = try allocator.create(Engine);

        engine.allocator = allocator;

        // Initialize Renderer
        const r = try allocator.create(render.Renderer);
        r.* = try render.Renderer.init(allocator, "config/window.toml");
        engine.renderer = r;

        // Initialize AssetManager
        const am = try allocator.create(asset_manager.AssetManager);
        am.* = try asset_manager.AssetManager.init(allocator);
        engine.asset_manager = am;

        // Initialize Scripting
        const s = try allocator.create(scripting.Scripting);
        s.* = try scripting.Scripting.init(allocator);
        engine.scripting = s;

        // Setup Lua bindings, passing the engine pointer so Lua functions can access engine components
        try engine.scripting.setupBindings(engine);

        // Load the main game script after bindings are set up
        try engine.scripting.doFile("scripts/game/main.lua");

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
        // Attempt to get the Lua _init, _update, and _draw functions
        if ((try self.scripting.lua.getGlobal("_init")) == .function) {
            _ = self.scripting.lua.autoCall(void, "__init", .{}) catch |err| {
                std.debug.print("Failed to call __init function at main.lua with err\n    \x1b[34m{}\x1b[0m\n", .{err});
            }; // Call _init()
            std.debug.print("Call __init()", .{});
        } else {
            self.scripting.lua.pop(1); // Pop the non-function value
            std.debug.print("Warning: _init() function not found in Lua script.\n", .{});
        }

        while (!self.shouldClose()) {
            // Call Lua's _update function
            if ((try self.scripting.lua.getGlobal("_update")) == .function) {
                _ = self.scripting.call(CallArgs{ .args = 0, .results = 0 }); // Call _update()
                std.debug.print("Call __update()", .{});
            } else {
                self.scripting.lua.pop(1); // Pop the non-function value
                std.debug.print("Warning: _update() function not found in Lua script. Game logic might not be updated.\n", .{});
            }

            // Call Lua's _draw function
            rl.beginDrawing();
            rl.clearBackground(.black); // Clear screen before Lua draws
            if ((try self.scripting.lua.getGlobal("_draw")) == .function) {
                _ = self.scripting.call(CallArgs{ .args = 0, .results = 0 }); // Call _draw()
                std.debug.print("Call __draw()", .{});
            } else {
                self.scripting.lua.pop(1); // Pop the non-function value
                std.debug.print("Warning: _draw() function not found in Lua script. Nothing will be drawn.\n", .{});
            }

            rl.drawFPS(5, 17); // Draw FPS from Zig
            rl.endDrawing();
        }
    }
};
