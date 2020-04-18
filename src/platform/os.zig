const builtin = @import("builtin");

const host = switch (builtin.os.tag) {
    .linux => @import("os/linux.zig"),
    else => @import("os/undefined.zig"),
};

usingnamespace host;
