const std = @import("std");

pub const Video = struct {
    buffer: [2048]u1, // 64 x 32

    pub fn init(video: *Video) void {
        std.mem.set(u1, video.buffer[0..], 0);
    }

    pub fn deinit(video: *Video, alloc: *std.mem.Allocator) void {
        alloc.destroy(video);
    }

    pub fn read(video: *Video, at: u11) u1 {
        return video.buffer[at];
    }

    pub fn write(video: *Video, at: u11, bit: u1) void {
        video.buffer[at] = bit;
    }
};
