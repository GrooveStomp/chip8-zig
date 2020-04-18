const std = @import("std");
const mem_pkg = @import("memory.zig");
const video_pkg = @import("video.zig");
const input_pkg = @import("input.zig");

const MemoryError = error{ProgramTooLarge};

pub const Bus = struct {
    input: *input_pkg.Input,
    memory: *mem_pkg.Memory,
    video: *video_pkg.Video,

    pub fn init(bus: *Bus, input: *input_pkg.Input, memory: *mem_pkg.Memory, video: *video_pkg.Video) void {
        bus.input = input;
        bus.memory = memory;
        bus.video = video;
    }

    pub fn deinit(bus: *Bus, alloc: *std.mem.Allocator) void {
        alloc.destroy(bus);
    }

    pub fn readMemory(bus: *Bus, at: u12) u8 {
        return bus.memory.read(at);
    }

    pub fn writeMemory(bus: *Bus, at: u12, data: u8) void {
        bus.memory.write(at, data);
    }

    pub fn readVideo(bus: *Bus, at: u11) u1 {
        return bus.video.read(at);
    }

    pub fn writeVideo(bus: *Bus, at: u11, bit: u1) void {
        bus.video.write(at, bit);
    }

    pub fn readInput(bus: *Bus, at: u4) u1 {
        return bus.input.read(at);
    }

    pub fn writeInput(bus: *Bus, at: u4, bit: u1) void {
        bus.input.write(at, bit);
    }

    pub fn loadProgram(bus: *Bus, mem: []const u8) !void {
        var i: u12 = 0x200;
        var max_size: u12 = 4096 - 0x200;

        if (mem.len > max_size) {
            return MemoryError.ProgramTooLarge;
        }

        while (i < mem.len + 0x200) : (i += 1) {
            bus.memory.write(i, mem[i - 0x200]);
        }
    }
};
