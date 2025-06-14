const std = @import("std");
const rl = @import("raylib");

pub const AssetManager = struct {
    allocator: std.mem.Allocator,
    textures: std.StringHashMap(rl.Texture2D),

    pub fn init(allocator: std.mem.Allocator) !AssetManager {
        const t = std.StringHashMap(rl.Texture2D).init(allocator);
        var asset_manager = AssetManager{
            .allocator = allocator,
            .textures = t,
        };
        try asset_manager.loadTexturesFromDir("assets/textures/");
        return asset_manager;
    }

    pub fn deinit(self: *AssetManager) void {
        var texture_iter = self.textures.valueIterator();
        while (texture_iter.next()) |tex| {
            rl.unloadTexture(tex.*);
        }
        self.textures.deinit();
    }

    fn loadTexturesFromDir(self: *AssetManager, path: [:0]const u8) !void {
        var textures_dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
        defer textures_dir.close();

        var iter = textures_dir.iterate();
        while (try iter.next()) |f| {
            if (f.kind == .file) {
                const full_path_str = try std.fmt.allocPrintZ(self.allocator, "{s}{s}", .{ path, f.name });
                defer self.allocator.free(full_path_str);

                const texture = blk: {
                    if (rl.loadTexture(full_path_str)) |loaded_texture| {
                        break :blk loaded_texture;
                    } else |err| {
                        std.debug.print("Failed to load texture: {s} with error '{s}'\n", .{ f.name, @errorName(err) });

                        const error_msg_buf = try std.fmt.allocPrintZ(self.allocator, "ERROR: {s}", .{f.name});
                        defer self.allocator.free(error_msg_buf);

                        const error_image = rl.genImageText(20, 20, error_msg_buf);
                        defer rl.unloadImage(error_image);

                        break :blk try rl.loadTextureFromImage(error_image);
                    }
                };
                const name = try self.allocator.dupe(u8, f.name);
                try self.textures.put(name, texture);
                std.debug.print("Loaded Texture: {s}\n", .{f.name});
            }
        }
        std.debug.print("\x1b[32m[ DONE ]\x1b[0m Finished Loading Textures.\n", .{});
    }

    pub fn getTexture(self: *AssetManager, name: [:0]const u8) ?*rl.Texture2D {
        if (self.textures.get(name)) |t| {
            return @constCast(&t);
        } else {
            return null;
        }
    }
};
