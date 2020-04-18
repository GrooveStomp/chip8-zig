const c = @cImport({
    @cInclude("X11/X.h");
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
});

const event = @import("../event.zig");
const common = @import("common.zig");

pub fn mapKey(key: u64) common.Key {
    return switch (key) {
        0x61 => common.Key.KEY_A,
        0x62 => common.Key.KEY_B,
        0x63 => common.Key.KEY_C,
        0x64 => common.Key.KEY_D,
        0x65 => common.Key.KEY_E,
        0x66 => common.Key.KEY_F,
        0x67 => common.Key.KEY_G,
        0x68 => common.Key.KEY_H,
        0x69 => common.Key.KEY_I,
        0x6A => common.Key.KEY_J,
        0x6B => common.Key.KEY_K,
        0x6C => common.Key.KEY_L,
        0x6D => common.Key.KEY_M,
        0x6E => common.Key.KEY_N,
        0x6F => common.Key.KEY_O,
        0x70 => common.Key.KEY_P,
        0x71 => common.Key.KEY_Q,
        0x72 => common.Key.KEY_R,
        0x73 => common.Key.KEY_S,
        0x74 => common.Key.KEY_T,
        0x75 => common.Key.KEY_U,
        0x76 => common.Key.KEY_V,
        0x77 => common.Key.KEY_W,
        0x78 => common.Key.KEY_X,
        0x79 => common.Key.KEY_Y,
        0x7A => common.Key.KEY_Z,
        c.XK_Left => common.Key.KEY_LEFT,
        c.XK_Right => common.Key.KEY_RIGHT,
        c.XK_Up => common.Key.KEY_UP,
        c.XK_Down => common.Key.KEY_DOWN,
        c.XK_Linefeed => common.Key.KEY_ENTER,
        c.XK_Escape => common.Key.KEY_ESC,
        c.XK_space => common.Key.KEY_SPACE,
        c.XK_semicolon => common.Key.KEY_SEMICOLON,
        c.XK_BackSpace => common.Key.KEY_BACKSPACE,
        c.XK_1 => common.Key.KEY_1,
        c.XK_2 => common.Key.KEY_2,
        c.XK_3 => common.Key.KEY_3,
        c.XK_4 => common.Key.KEY_4,
        c.XK_5 => common.Key.KEY_5,
        c.XK_6 => common.Key.KEY_6,
        c.XK_7 => common.Key.KEY_7,
        c.XK_8 => common.Key.KEY_8,
        c.XK_9 => common.Key.KEY_9,
        c.XK_0 => common.Key.KEY_0,
        c.XK_Shift_L => common.Key.KEY_LSHIFT,
        c.XK_Shift_R => common.Key.KEY_RSHIFT,
        c.XK_Control_L => common.Key.KEY_LCTRL,
        c.XK_Control_R => common.Key.KEY_RCTRL,
        else => common.Key.KEY_NONE,
    };
}

pub fn processEvent(pressedKeys: []bool, ev: *event.Event) void {
    switch (ev.type) {
        c.KeyPress => {
            var sym: c.KeySym = c.XLookupKeysym(@ptrCast(*c.XKeyEvent, &ev.xkey), 0);
            var mapped = @enumToInt(mapKey(sym));
            pressedKeys[mapped] = true;

            var e: *c.XKeyEvent = @ptrCast(*c.XKeyEvent, ev);
            _ = c.XLookupString(e, null, 0, &sym, null);
            mapped = @enumToInt(mapKey(sym));
            pressedKeys[mapped] = true;
        },
        c.KeyRelease => {
            var sym: c.KeySym = c.XLookupKeysym(@ptrCast(*c.XKeyEvent, &ev.xkey), 0);
            var mapped = @enumToInt(mapKey(sym));
            pressedKeys[mapped] = false;

            var e: *c.XKeyEvent = @ptrCast(*c.XKeyEvent, ev);
            _ = c.XLookupString(e, null, 0, &sym, null);
            mapped = @enumToInt(mapKey(sym));
            pressedKeys[mapped] = false;
        },
        c.ButtonPress => {
            // TODO: Mouse
        },
        c.ButtonRelease => {
            // TODO: Mouse
        },
        c.MotionNotify => {
            // TODO: Mouse
        },
        else => {},
    }
}
