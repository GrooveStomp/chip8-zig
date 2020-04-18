const builtin = @import("builtin");

const host = switch(builtin.os) {
    .linux => @import("os/linux.zig"),
    else => @import("os/undefined.zig"),
};

usingnamespace host;
