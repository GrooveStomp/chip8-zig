const builtin = @import("builtin");

const platform = switch(builtin.os) {
    .linux => @import("event/linux.zig"),
    else => @import("event/undefined.zig"),
};

pub const Event = platform.Event;
