const builtin = @import("builtin");

const host = switch(builtin.os) {
    .linux => @import("sound/linux.zig"),
    else => @import("sound/undefined.zig"),
};

usingnamespace host;
