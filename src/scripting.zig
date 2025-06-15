const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const CallArgs = zlua.Lua.CallArgs;
const LuaState = zlua.LuaState;
const rl = @import("raylib");
const Engine = @import("engine.zig").Engine;
const Drawable = @import("renderer.zig").Drawable;
pub const CFn = *const fn (state: ?*LuaState) callconv(.C) c_int;

/// Helper function to get the engine pointer from a Lua state.
/// We get it from an "upvalue", which is a variable associated with the C closure.
fn getEngine(lua: *Lua) !*Engine {
    // The pointer is at upvalue index 1.
    return lua.toUserdata(Engine, Lua.upvalueIndex(1));
}

/// Logs a message from Lua to the console.
fn log(lua: *Lua) c_int {
    const msg = lua.toString(1) catch |err| {
        std.debug.print("Lua `log` error: {s}\n", .{@errorName(err)});
        return 0;
    };
    std.debug.print("\x1b[34m[Lua Log]: {s}\x1b[0m\n", .{msg});
    return 0;
}

/// Queues a texture to be drawn.
/// Lua API: Engine:draw_texture(name, x, y, rotation, scale, r, g, b, a)
fn draw_texture(lua: *Lua) c_int {
    const engine = getEngine(lua) catch |err| {
        std.debug.print("draw_texture error: could not get engine pointer: {s}\n", .{@errorName(err)});
        return 0;
    };

    if (lua.getTop() < 9) {
        std.debug.print("draw_texture error: 9 arguments required.\n", .{});
        return 0;
    }

    const name = lua.toString(1) catch {
        std.debug.print("draw_texture error: argument 1 (name) must be a string.\n", .{});
        return 0;
    };

    const texture = engine.asset_manager.getTexture(name) orelse {
        std.debug.print("draw_texture warning: texture '{s}' not found.\n", .{name});
        return 0;
    };

    const x: f32 = @floatCast(lua.toNumber(2) catch 0);
    const y: f32 = @floatCast(lua.toNumber(3) catch 0);
    const rotation: f32 = @floatCast(lua.toNumber(4) catch 0.0);
    const scale: f32 = @floatCast(lua.toNumber(5) catch 1.0);
    const r: u8 = @as(u8, @intFromFloat(lua.toNumber(6) catch 255));
    const g: u8 = @as(u8, @intFromFloat(lua.toNumber(7) catch 255));
    const b: u8 = @as(u8, @intFromFloat(lua.toNumber(8) catch 255));
    const a: u8 = @as(u8, @intFromFloat(lua.toNumber(9) catch 255));

    engine.renderer.queue(.{
        .texture = .{
            .texture = texture,
            .position = .{ .x = x, .y = y },
            .rotation = rotation,
            .scale = scale,
            .tint = rl.Color.init(r, g, b, a),
        },
    }) catch |err| {
        std.debug.print("draw_texture error: failed to queue drawable: {s}", .{@errorName(err)});
    };

    return 0;
}

/// Takes in the filename and scale of a texture, returns the width of the texture, scaled.
/// Lua API: Engine:get_texture_width(filename, scale)
fn get_texture_width(lua: *Lua) c_int {
    const engine = getEngine(lua) catch |err| {
        std.debug.print("get_texture_width error: could not get engine pointer: {s}\n", .{@errorName(err)});
        return 0;
    };

    if (lua.getTop() < 2) {
        std.debug.print("get_texture_width error: 2 arguments required. (texture: string, scale: float) \n", .{});
        return 0;
    }

    const tname: [:0]const u8 = lua.toString(1) catch undefined;
    const t = engine.asset_manager.getTexture(tname) orelse {
        std.debug.print("draw_texture warning: texture '{s}' not found.\n", .{tname});
        return 0;
    };
    const scale: f32 = @floatCast(lua.toNumber(2) catch 1.0);
    const num: f32 = @as(f32, @floatFromInt(t.width)) * scale;
    lua.pushNumber(num);
    return 1;
}

/// Takes in the filename and scale of a texture, returns the height of the texture, scaled.
/// Lua API: Engine:get_texture_height(filename, scale)
fn get_texture_height(lua: *Lua) c_int {
    const engine = getEngine(lua) catch |err| {
        std.debug.print("get_texture_height error: could not get engine pointer: {s}\n", .{@errorName(err)});
        return 0;
    };

    if (lua.getTop() < 2) {
        std.debug.print("get_texture_height error: 2 arguments required. (texture: string, scale: float) \n", .{});
        return 0;
    }

    const tname: [:0]const u8 = lua.toString(1) catch undefined;
    const t = engine.asset_manager.getTexture(tname) orelse {
        std.debug.print("draw_texture warning: texture '{s}' not found.\n", .{tname});
        return 0;
    };
    const scale: f32 = @floatCast(lua.toNumber(2) catch 1.0);
    const num: f32 = @as(f32, @floatFromInt(t.height)) * scale;
    lua.pushNumber(num);
    return 1;
}

/// Queues a circle to be drawn.
/// Lua API: Engine:draw_circle(x, y, radius, r, g, b, a)
fn draw_circle(lua: *Lua) c_int {
    const engine = getEngine(lua) catch |err| {
        std.debug.print("draw_circle error: could not get engine pointer: {s}\n", .{@errorName(err)});
        return 0;
    };

    if (lua.getTop() < 7) {
        std.debug.print("draw_circle error: 7 arguments required.\n", .{});
        return 0;
    }

    const x: i32 = @intFromFloat(lua.toNumber(1) catch 0);
    const y: i32 = @intFromFloat(lua.toNumber(2) catch 0);
    const radius: f32 = @floatCast(lua.toNumber(3) catch 10.0);
    const r: u8 = @as(u8, @intFromFloat(lua.toNumber(4) catch 255));
    const g: u8 = @as(u8, @intFromFloat(lua.toNumber(5) catch 255));
    const b: u8 = @as(u8, @intFromFloat(lua.toNumber(6) catch 255));
    const a: u8 = @as(u8, @intFromFloat(lua.toNumber(7) catch 255));

    engine.renderer.queue(.{
        .circle = .{
            .x = x,
            .y = y,
            .radius = radius,
            .color = rl.Color.init(r, g, b, a),
        },
    }) catch |err| {
        std.debug.print("draw_circle error: failed to queue drawable: {s}", .{@errorName(err)});
    };

    return 0;
}

/// Checks if a keyboard key is currently held down.
fn is_key_down(lua: *Lua) c_int {
    const key_name = lua.toString(1) catch {
        lua.pushBoolean(false);
        return 1;
    };
    const key_code = std.meta.stringToEnum(rl.KeyboardKey, key_name) orelse {
        std.debug.print("no keycode with name: {s}\n", .{key_name});
        lua.pushBoolean(false);
        return 1;
    };
    lua.pushBoolean(rl.isKeyDown(key_code));
    return 1;
}

/// Checks if a keyboard key was just pressed in this frame.
fn is_key_pressed(lua: *Lua) c_int {
    const key_name = lua.toString(1) catch {
        lua.pushBoolean(false);
        return 1;
    };
    const key_code = std.meta.stringToEnum(rl.KeyboardKey, key_name) orelse {
        lua.pushBoolean(false);
        return 1;
    };
    lua.pushBoolean(rl.isKeyPressed(key_code));
    return 1;
}

pub const Scripting = struct {
    lua: *Lua,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Scripting {
        var lua_state = try Lua.init(allocator);
        _ = lua_state.openLibs();
        return Scripting{
            .lua = lua_state,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Scripting) void {
        self.lua.deinit();
    }

    pub fn setupBindings(self: *Scripting, engine_ptr: *Engine) !void {
        self.lua.newTable(); // Create the 'Engine' table

        const addEngineFunc = struct {
            fn add(l: *Lua, ptr: *Engine, name: [:0]const u8, func: CFn) !void {
                l.pushLightUserdata(ptr);
                l.pushClosure(func, 1); // 1 upvalue (the engine_ptr)
                l.setField(-2, name);
            }
        }.add;

        // --- Bind all functions to the 'Engine' table ---
        try addEngineFunc(self.lua, engine_ptr, "draw_texture", zlua.wrap(draw_texture));
        try addEngineFunc(self.lua, engine_ptr, "get_texture_width", zlua.wrap(get_texture_width));
        try addEngineFunc(self.lua, engine_ptr, "get_texture_height", zlua.wrap(get_texture_height));
        try addEngineFunc(self.lua, engine_ptr, "draw_circle", zlua.wrap(draw_circle));
        try addEngineFunc(self.lua, engine_ptr, "log", zlua.wrap(log));
        self.lua.setGlobal("Engine"); // Set the table as a global

        self.lua.newTable();
        const addInputFunc = struct {
            fn add(l: *Lua, name: [:0]const u8, func: CFn) !void {
                l.pushFunction(func);
                l.setField(-2, name);
            }
        }.add;

        try addInputFunc(self.lua, "is_key_down", zlua.wrap(is_key_down));
        try addInputFunc(self.lua, "is_key_pressed", zlua.wrap(is_key_pressed));
        self.lua.setGlobal("Input");
    }

    pub fn doString(self: *Scripting, code: []const u8) !void {
        self.lua.doString(code);
    }

    pub fn doFile(self: *Scripting, path: [:0]const u8) !void {
        try self.lua.doFile(path);
    }

    pub fn call(self: *Scripting, args: CallArgs) void {
        self.lua.call(args);
    }
};
