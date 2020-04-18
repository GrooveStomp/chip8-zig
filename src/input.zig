const std = @import("std");

pub const Input = struct {
    keys: [16]u1,

    pub fn init(input: *Input) void {
        std.mem.set(u1, input.keys[0..], 0);
    }

    pub fn deinit(input: *Input, alloc: *std.mem.Allocator) void {
        alloc.destroy(input);
    }

    pub fn read(input: *Input, at: u4) u1 {
        return input.keys[at];
    }

    pub fn write(input: *Input, at: u4, bit: u1) void {
        input.keys[at] = bit;
    }
};
