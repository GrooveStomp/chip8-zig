const builtin = @import("builtin");

const platform = switch (builtin.os.tag) {
    .linux => @import("event/linux.zig"),
    else => @import("event/undefined.zig"),
};

pub const Event = platform.Event;
