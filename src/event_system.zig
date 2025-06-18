const std = @import("std");

/// Simple Event Delegate
pub const Event = struct {
    pub fn Callback(comptime T: type) type {
        return *const fn (data: T) void;
    }

    pub fn create(comptime T: type) type {
        return struct {
            allocator: std.mem.Allocator,
            name: []const u8,
            listeners: std.ArrayList(Callback(T)),

            /// Initialize the event, providing the allocator and a name
            pub fn init(allocator: std.mem.Allocator, name: []const u8) @This() {
                return .{
                    .allocator = allocator,
                    .name = name,
                    .listeners = std.ArrayList(Callback(T)).init(allocator),
                };
            }

            /// Deinitialization function to free allocated memory
            pub fn deinit(self: *@This()) void {
                self.listeners.deinit();
            }

            /// Connects a listener to the event.
            /// Returns the index of the new listener or an error if allocation fails.
            pub fn connect(self: *@This(), listener: Callback(T)) !usize {
                self.listeners.append(listener) catch |err| {
                    std.debug.print("Failed to connect listener: {any}\n", .{err});
                    return err; // Propagate allocation errors
                };
                return self.listeners.items.len - 1; // Return the index of the newly added listener
            }

            /// Disconnects the listener at the given index.
            /// Returns true if successfully disconnected, false if the index is out of bounds.
            pub fn disconnect(self: *@This(), index: usize) bool {
                if (index >= self.listeners.items.len) {
                    return false; // Index out of bounds
                }
                _ = self.listeners.swapRemove(index); // swapRemove is efficient for ArrayList
                return true;
            }

            /// Emits the event, calling all connected listeners with the provided arguments.
            /// The args must be of the same signature type as the Event.
            pub fn emit(self: *@This(), args: T, mutex: ?*std.Thread.Mutex) void {
                for (self.listeners.items) |listener| {
                    if (mutex != null) {
                        mutex.?.lock();
                        listener(args);
                        mutex.?.unlock();
                    } else {
                        listener(args);
                    }
                }
            }
        };
    }
};

test "event" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create an Event that expects its callbacks to take a *usize argument
    const MyIntEvent = Event.create(*usize);
    var my_int_event = MyIntEvent.init(allocator, "MyIntEvent");
    defer my_int_event.deinit();

    var call_count: usize = 0;

    // Listener 1 now explicitly takes a *usize
    const listener1_for_int_event: Event.Callback(*usize) = struct {
        fn func(context: *usize) void {
            context.* += 1;
            std.debug.print("Listener 1 (int) called with: {d}\n", .{context.*});
        }
    }.func;

    // Listener 2 now explicitly takes a *usize
    const listener2_for_int_event: Event.Callback(*usize) = struct {
        fn func(context: *usize) void {
            context.* += 1;
            std.debug.print("Listener 2 (int) called with: {d}\n", .{context.*});
        }
    }.func;

    _ = try my_int_event.connect(listener1_for_int_event);
    const index2 = try my_int_event.connect(listener2_for_int_event);
    _ = try my_int_event.connect(listener1_for_int_event); // Connect listener1 again

    // When emitting, you must provide an argument of type *usize
    my_int_event.emit(&call_count, null);
    try std.testing.expectEqual(call_count, 3); // Listener1 called twice, Listener2 called once

    call_count = 0; // Reset for next emit
    _ = my_int_event.disconnect(index2); // Disconnect listener2

    my_int_event.emit(&call_count, null);
    try std.testing.expectEqual(call_count, 2); // Listener1 called twice

    // --- Example with a different event type (e.g., a string slice) ---
    const MyStringEvent = Event.create([]const u8);
    var my_string_event = MyStringEvent.init(allocator, "MyStringEvent");
    defer my_string_event.deinit();

    const string_listener1: Event.Callback([]const u8) = struct {
        fn func(message: []const u8) void {
            std.debug.print("String Listener 1 received: {s}\n", .{message});
        }
    }.func;

    const string_listener2: Event.Callback([]const u8) = struct {
        fn func(message: []const u8) void {
            std.debug.print("String Listener 2 received: {s}\n", .{message});
        }
    }.func;

    _ = try my_string_event.connect(string_listener1);
    _ = try my_string_event.connect(string_listener2);

    my_string_event.emit("Hello, Zig Events!", null);
    // No direct assertion for this, but output confirms it works.
}

test "multithreaded event" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var event_mutex = std.Thread.Mutex{}; // Mutex value

    // Create an Event that expects its callbacks to take a *usize argument
    const MyIntEvent = Event.create(*usize);
    var my_int_event = MyIntEvent.init(allocator, "MyIntEvent");
    defer my_int_event.deinit();

    var call_count: usize = 0;

    // Listener 1 now explicitly takes a *usize
    const listener1_for_int_event: Event.Callback(*usize) = struct {
        fn func(context: *usize) void {
            context.* += 1;
            std.debug.print("Listener 1 (int) called with: {d}\n", .{context.*});
        }
    }.func;

    // Listener 2 now explicitly takes a *usize
    const listener2_for_int_event: Event.Callback(*usize) = struct {
        fn func(context: *usize) void {
            context.* += 1;
            std.debug.print("Listener 2 (int) called with: {d}\n", .{context.*});
        }
    }.func;

    _ = try my_int_event.connect(listener1_for_int_event);
    const index2 = try my_int_event.connect(listener2_for_int_event);
    _ = try my_int_event.connect(listener1_for_int_event); // Connect listener1 again

    // Define a function that will be executed in the new thread.
    // This function explicitly takes the event instance, the call_count pointer,
    // and the mutex pointer, then calls the emit method.
    const thread_func = struct {
        fn run(event_instance: *MyIntEvent, count_ptr: *usize, mutex_ptr: *std.Thread.Mutex) void {
            event_instance.emit(count_ptr, mutex_ptr);
        }
    }.run;

    // Spawn the thread, passing pointers to `my_int_event`, `call_count`, and `event_mutex`.
    const thread = try std.Thread.spawn(.{}, thread_func, .{ &my_int_event, &call_count, &event_mutex });
    thread.join(); // Wait for the thread to complete
    try std.testing.expectEqual(call_count, 3); // Listener1 called twice, Listener2 called once

    call_count = 0; // Reset for next emit
    _ = my_int_event.disconnect(index2); // Disconnect listener2

    // Emit again in the main thread (without a mutex, as per the original test logic)
    my_int_event.emit(&call_count, null);
    try std.testing.expectEqual(call_count, 2); // Listener1 called twice
}
