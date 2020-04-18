const std = @import("std");

pub const Memory = struct {
    memory: [4096]u8,

    pub fn init(mem: *Memory) void {
        std.mem.set(u8, mem.memory[0..], 0);
    }

    pub fn deinit(mem: *Memory, alloc: *std.mem.Allocator) void {
        alloc.destroy(mem);
    }

    pub fn read(mem: *Memory, at: u12) u8 {
        return mem.memory[at];
    }

    pub fn write(mem: *Memory, at: u12, data: u8) void {
        mem.memory[at] = data;
    }
};
