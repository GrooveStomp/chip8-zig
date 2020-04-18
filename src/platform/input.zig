const builtin = @import("builtin");
const std = @import("std");
const event = @import("event.zig");

const host = switch(builtin.os) {
    .linux => @import("input/linux.zig"),
    else => @import("input/undefined.zig"),
};

usingnamespace @import("input/common.zig");

const ButtonState = struct {
    pressed: bool = false,
    released: bool = false,
    held: bool = false,
};

// TODO: mouse, joypad

pub const Input = struct {
    key_states: [@memberCount(Key)]ButtonState,
    new_presses: [@memberCount(Key)]bool,
    old_presses: [@memberCount(Key)]bool,

    pub fn init(input: *Input) void {
    }

    pub fn deinit(input: *Input, alloc: *std.mem.Allocator) void {
        alloc.destroy(input);
    }

    pub fn update(input: *Input) void {
        for (input.key_states) |*key_state, i| {
            key_state.*.pressed = false;
            key_state.*.released = false;

            if (input.new_presses[i] != input.old_presses[i]) {
                if (input.new_presses[i]) {
                    key_state.*.pressed = !key_state.*.held;
                    key_state.*.held = true;
                } else {
                    key_state.*.released = true;
                    key_state.*.held = false;
                }
            }

            input.old_presses[i] = input.new_presses[i];
        }
    }

    pub fn getKey(input: Input, key: Key) ButtonState {
        return input.key_states[@enumToInt(key)];
    }

    pub fn processEvent(input: *Input, ev: *event.Event) void {
        host.processEvent(input.new_presses[0..], ev);
    }
};
