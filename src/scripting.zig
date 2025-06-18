/// This sourcefile contains all of the code related to the Lua API for the engine.
/// ( Bindings and the function definitions. )
/// This will probably change in the future and be turned into a module.
/// For now its a simple monolithic file because I was originally just making flappy bird
/// but in the process I made a whole game engine.
const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const CallArgs = zlua.Lua.CallArgs;
const LuaState = zlua.LuaState;
const rl = @import("raylib");
const Engine = @import("engine.zig").Engine;
const Drawable = @import("renderer.zig").Drawable;
pub const CFn = *const fn (state: ?*LuaState) callconv(.C) c_int;
const event_system = @import("event_system.zig");
const Event = event_system.Event;

// ##################################################
// #                  ENGINE                        #
// ##################################################
/// Helper function to get the engine pointer from a Lua state.
/// We get it from an "upvalue", which is a variable associated with the C closure.
fn getEngine(lua: *Lua) !*Engine {
    return lua.toUserdata(Engine, Lua.upvalueIndex(1));
}

fn getFrameTime(lua: *Lua) c_int {
    const engine = getEngine(lua) catch |err| {
        std.debug.print("draw_texture error: could not get engine pointer: {s}\n", .{@errorName(err)});
        return 0;
    };
    const delta: f32 = engine.renderer.get_frame_time();
    lua.pushNumber(delta);
    return 1;
}

/// Logs a message from Lua to the console.
/// Lua API: Engine:log(message: string)
fn log(lua: *Lua) c_int {
    const msg = lua.toString(1) catch |err| {
        std.debug.print("Lua `log` error: {s}\n", .{@errorName(err)});
        return 0;
    };
    std.debug.print("\x1b[34m[Lua Log]: {s}\x1b[0m\n", .{msg});
    return 0;
}

// ##################################################
// #                 COLLISION                      #
// ##################################################
const RectangleMetatableName = "Engine.Rectangle";

/// Metamethod to get fields from a Rectangle userdata (e.g., rect.x).
/// Lua API: rect.x / rect.y / rect.width / rect.height
/// This function is generic and uses comptime to avoid repetitive code.
fn rect_index(lua: *Lua) c_int {
    const rect: *rl.Rectangle = lua.toUserdata(rl.Rectangle, 1) catch |err| {
        std.debug.print("rect_index error: could not get userdata: {s}\n", .{@errorName(err)});
        return 0;
    };
    const key = lua.toString(2) catch |err| {
        std.debug.print("rect_index error: key is not a string: {s}\n", .{@errorName(err)});
        return 0;
    };

    inline for (@typeInfo(rl.Rectangle).@"struct".fields) |field| {
        if (std.mem.eql(u8, key, field.name)) {
            lua.pushNumber(@field(rect, field.name));
            return 1;
        }
    }
    return 0;
}

/// Metamethod to set fields on a Rectangle userdata (e.g., rect.x = 10).
/// Lua API: rect.x = value / rect.y = value / rect.width = value / rect.height = value
/// This function is also generic and uses comptime.
fn rect_newindex(lua: *Lua) c_int {
    const rect: *rl.Rectangle = lua.toUserdata(rl.Rectangle, 1) catch |err| {
        std.debug.print("rect_newindex error: could not get userdata: {s}\n", .{@errorName(err)});
        return 0;
    };
    const key = lua.toString(2) catch |err| {
        std.debug.print("rect_newindex error: key is not a string: {s}\n", .{@errorName(err)});
        return 0;
    };
    const value = lua.toNumber(3) catch |err| {
        std.debug.print("rect_newindex error: value is not a number: {s}\n", .{@errorName(err)});
        return 0;
    };

    inline for (@typeInfo(rl.Rectangle).@"struct".fields) |field| {
        if (std.mem.eql(u8, key, field.name)) {
            @field(rect, field.name) = @floatCast(value);
            return 0;
        }
    }
    return 0;
}

/// Creates a new Rectangle userdata.
/// Lua API: Rect.new(x, y, width, height)
fn rect_new(lua: *Lua) c_int {
    if (lua.getTop() < 4) {
        std.debug.print("Rect.new error: 4 arguments required (x, y, width, height).\n", .{});
        return 0;
    }
    const x: f32 = @floatCast(lua.toNumber(1) catch 0);
    const y: f32 = @floatCast(lua.toNumber(2) catch 0);
    const width: f32 = @floatCast(lua.toNumber(3) catch 0);
    const height: f32 = @floatCast(lua.toNumber(4) catch 0);

    const rect_ptr = lua.newUserdata(rl.Rectangle, 0);

    rect_ptr.* = rl.Rectangle{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    };

    lua.pushValue(zlua.registry_index);

    _ = lua.getField(-1, RectangleMetatableName);

    lua.remove(-2);

    lua.setMetatable(-2);

    return 1;
}

/// Checks for collision between two Rectangle userdatas.
/// Lua API: Rect.check_collision(rect1, rect2)
fn check_collision_recs(lua: *Lua) c_int {
    if (lua.getTop() < 2) {
        std.debug.print("Rect.check_collision error: 2 arguments required (rect1, rect2).\n", .{});
        lua.pushBoolean(false);
        return 1;
    }
    const rect1: *rl.Rectangle = lua.toUserdata(rl.Rectangle, 1) catch |err| {
        std.debug.print("Rect.check_collision error: argument 1 is not a Rectangle: {s}\n", .{@errorName(err)});
        lua.pushBoolean(false);
        return 1;
    };
    const rect2: *rl.Rectangle = lua.toUserdata(rl.Rectangle, 2) catch |err| {
        std.debug.print("Rect.check_collision error: argument 2 is not a Rectangle: {s}\n", .{@errorName(err)});
        lua.pushBoolean(false);
        return 1;
    };

    const collision = rl.checkCollisionRecs(rect1.*, rect2.*);

    lua.pushBoolean(collision);
    return 1;
}

// ##################################################
// #                 RENDERING                      #
// ##################################################
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

/// Queues a rectangle to be drawn.
/// Lua API: Engine:draw_rect(x, y, width, height, r, g, b, a)
fn draw_rectangle(lua: *Lua) c_int {
    const engine = getEngine(lua) catch |err| {
        std.debug.print("draw_rect error: could not get engine pointer: {s}\n", .{@errorName(err)});
        return 0;
    };

    if (lua.getTop() < 8) {
        std.debug.print("draw_rect error: 8 arguments required.\n", .{});
        return 0;
    }

    const x: i32 = @intFromFloat(lua.toNumber(1) catch 0);
    const y: i32 = @intFromFloat(lua.toNumber(2) catch 0);
    const w: i32 = @intFromFloat(lua.toNumber(3) catch 0);
    const h: i32 = @intFromFloat(lua.toNumber(4) catch 0);
    const r: u8 = @as(u8, @intFromFloat(lua.toNumber(5) catch 255));
    const g: u8 = @as(u8, @intFromFloat(lua.toNumber(6) catch 255));
    const b: u8 = @as(u8, @intFromFloat(lua.toNumber(7) catch 255));
    const a: u8 = @as(u8, @intFromFloat(lua.toNumber(8) catch 255));

    engine.renderer.queue(.{
        .rect = .{ .x = x, .y = y, .width = w, .height = h, .color = rl.Color.init(r, g, b, a) },
    }) catch |err| {
        std.debug.print("draw_rect error: failed to queue drawable: {s}", .{@errorName(err)});
    };

    return 0;
}

fn draw_text(lua: *Lua) c_int {
    const engine = getEngine(lua) catch |err| {
        std.debug.print("draw_text error: could not get engine pointer: {s}\n", .{@errorName(err)});
        return 0;
    };

    if (lua.getTop() < 8) {
        std.debug.print("draw_text error: 8 arguments required.\n", .{});
        return 0;
    }

    const msg: [:0]const u8 = lua.toString(1) catch "";
    const x: i32 = @intFromFloat(lua.toNumber(2) catch 0);
    const y: i32 = @intFromFloat(lua.toNumber(3) catch 0);
    const size: i32 = @intFromFloat(lua.toNumber(4) catch 0);
    const r: u8 = @as(u8, @intFromFloat(lua.toNumber(5) catch 255));
    const g: u8 = @as(u8, @intFromFloat(lua.toNumber(6) catch 255));
    const b: u8 = @as(u8, @intFromFloat(lua.toNumber(7) catch 255));
    const a: u8 = @as(u8, @intFromFloat(lua.toNumber(8) catch 255));

    engine.renderer.queue(.{
        .text = .{ .message = msg, .x = x, .y = y, .size = size, .color = rl.Color.init(r, g, b, a) },
    }) catch |err| {
        std.debug.print("draw_text error: failed to queue drawable: {s}", .{@errorName(err)});
    };

    return 0;
}

// ##################################################
// #                   INPUT                        #
// ##################################################
/// Checks if a keyboard key is currently held down.
/// Lua API: Input.is_key_down(key_name: string)
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
/// Lua API: Input.is_key_pressed(key_name: string)
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

// ##################################################
// #                  SCRIPTING                     #
// ##################################################
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
        self.lua.newTable();

        const addEngineFunc = struct {
            fn add(l: *Lua, ptr: *Engine, name: [:0]const u8, func: CFn) !void {
                l.pushLightUserdata(ptr);
                l.pushClosure(func, 1);
                l.setField(-2, name);
            }
        }.add;

        try addEngineFunc(self.lua, engine_ptr, "draw_texture", zlua.wrap(draw_texture));
        try addEngineFunc(self.lua, engine_ptr, "get_texture_width", zlua.wrap(get_texture_width));
        try addEngineFunc(self.lua, engine_ptr, "get_texture_height", zlua.wrap(get_texture_height));
        try addEngineFunc(self.lua, engine_ptr, "draw_circle", zlua.wrap(draw_circle));
        try addEngineFunc(self.lua, engine_ptr, "draw_rect", zlua.wrap(draw_rectangle));
        try addEngineFunc(self.lua, engine_ptr, "draw_text", zlua.wrap(draw_text));
        try addEngineFunc(self.lua, engine_ptr, "log", zlua.wrap(log));
        try addEngineFunc(self.lua, engine_ptr, "get_frame_time", zlua.wrap(getFrameTime));
        self.lua.setGlobal("Engine");

        self.lua.newTable();
        const addGlobalFunc = struct {
            fn add(l: *Lua, name: [:0]const u8, func: CFn) !void {
                l.pushFunction(func);
                l.setField(-2, name);
            }
        }.add;

        try addGlobalFunc(self.lua, "is_key_down", zlua.wrap(is_key_down));
        try addGlobalFunc(self.lua, "is_key_pressed", zlua.wrap(is_key_pressed));
        self.lua.setGlobal("Input");

        // Setup the Rectangle Metatable and the Rect Global Table
        try self.lua.newMetatable(RectangleMetatableName);
        try addGlobalFunc(self.lua, "__index", zlua.wrap(rect_index));
        try addGlobalFunc(self.lua, "__newindex", zlua.wrap(rect_newindex));
        self.lua.pop(1);

        self.lua.newTable();
        try addGlobalFunc(self.lua, "new", zlua.wrap(rect_new));
        try addGlobalFunc(self.lua, "check_collision", zlua.wrap(check_collision_recs));
        self.lua.setGlobal("Rect");
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
