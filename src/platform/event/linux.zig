const c = @cImport({
    @cInclude("X11/Xlib.h");
});

pub const Event = c.XEvent;
