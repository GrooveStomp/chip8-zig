const c = @cImport({
    @cInclude("X11/X.h");
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
    @cInclude("GL/gl.h");
    @cInclude("GL/glx.h");
    @cInclude("stdlib.h");
});
const std = @import("std");
const event = @import("../event.zig");

const WindowAttributes = struct {
    screen_width: u32 = undefined,
    screen_height: u32 = undefined,
    window_width: u32 = undefined,
    window_height: u32 = undefined,
    view_x: u32 = undefined,
    view_y: u32 = undefined,
    view_width: u32 = undefined,
    view_height: u32 = undefined,
    pixel_width: u32 = undefined,
    pixel_height: u32 = undefined,
    pixel_x: f32 = undefined,
    pixel_y: f32 = undefined,
    sub_pixel_offset_x: f32 = undefined,
    sub_pixel_offset_y: f32 = undefined,

    pub fn updateViewport(self: *WindowAttributes) void {
        var width = self.screen_width * self.pixel_width;
        var height = self.screen_height * self.pixel_height;
        var aspect = @intToFloat(f32, width) / @intToFloat(f32, height);

        self.view_width = self.window_width;
        self.view_height = @floatToInt(u32, @intToFloat(f32, self.view_width) / aspect);

        if (self.view_height > self.window_height) {
            self.view_height = self.window_height;
            self.view_width = @floatToInt(u32, @intToFloat(f32, self.view_height) * aspect);
        }

        self.view_x = (self.window_width - self.view_width) / 2;
        self.view_y = (self.window_height - self.view_height) / 2;
    }
};

const Rgba = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Pixel = extern union {
    int: u32,
    rgba: Rgba,
};

pub fn rand() f64 {
    return @intToFloat(f64, c.rand()) / @intToFloat(f64, c.RAND_MAX);
}

pub fn srand(s: u8) void {
    c.srand(s);
}

pub fn newPixel(r: f32, g: f32, b: f32, a: f32) Pixel {
    var red = @floatToInt(u8, r * 255.0);
    var green = @floatToInt(u8, g * 255.0);
    var blue = @floatToInt(u8, b * 255.0);
    var alpha = @floatToInt(u8, a * 255.0);
    var p = Pixel{ .rgba = Rgba{ .r=red, .g=green, .b=blue, .a=alpha } };
    return p;
}

pub const Os = struct {
    display: ?*c.Display = null,
    window_root: c.Window = undefined,
    window: c.Window = undefined,
    visual_info: ?*c.XVisualInfo = null,
    color_map: c.Colormap = undefined,
    x_window_atts: c.XSetWindowAttributes = undefined,
    gl_device_ctx: c.GLXContext = undefined,
    gl_render_ctx: c.GLXContext = undefined,
    gl_buffer: c.GLuint = undefined,
    gl_swap_interval: ?extern fn() void = null,
    texture: []u32 = undefined,
    has_input_focus: bool = false,
    window_atts: WindowAttributes = undefined,
    texture_width: u32 = undefined,
    texture_height: u32 = undefined,

    pub fn init(os: *Os, width: u32, height: u32, scale: u32, alloc: *std.mem.Allocator) !void {
        os.window_atts = WindowAttributes {
            .screen_width = width * scale,
            .screen_height = height * scale,
            .pixel_width = 1,
            .pixel_height = 1,
            .pixel_x = (2.0 / @intToFloat(f32, width * scale)),
            .pixel_y = (2.0 / @intToFloat(f32, height * scale)),
            .sub_pixel_offset_x = 0.0,
            .sub_pixel_offset_y = 0.0,
        };

        os.texture_width = width;
        os.texture_height = height;
        os.texture = try alloc.alloc(u32, width * height);
        std.mem.set(u32, os.texture[0..], 0);

        var success = c.XInitThreads();
        if (success < 0) return error.Unexpected;

        os.display = c.XOpenDisplay(null);
        if (os.display == null) return error.Unexpected;

        os.window_root = c.XDefaultRootWindow(os.display);

        var gl_atts = [_]c.GLint{c.GLX_RGBA, c.GLX_DEPTH_SIZE, 24, c.GLX_DOUBLEBUFFER, c.None};
        os.visual_info = c.glXChooseVisual(os.display, 0, @ptrCast([*c]c_int, &gl_atts));
        if (os.visual_info == null) return error.Unexpected;

        var visual_info = @ptrCast(*c.XVisualInfo, os.visual_info);
        os.color_map = c.XCreateColormap(os.display, os.window_root, visual_info.*.visual, c.AllocNone);
        os.x_window_atts.colormap = os.color_map;

        os.x_window_atts.event_mask = c.ExposureMask | c.KeyPressMask | c.KeyReleaseMask | c.ButtonPressMask | c.ButtonReleaseMask | c.PointerMotionMask | c.FocusChangeMask | c.StructureNotifyMask;

        os.window = c.XCreateWindow(os.display, os.window_root, 30, 30, width * scale, height * scale, 0, visual_info.*.depth, c.InputOutput, visual_info.*.visual, c.CWColormap | c.CWEventMask, &os.x_window_atts);

        var wm_delete = c.XInternAtom(os.display, "WM_DELETE_WINDOW", 1);
        success = c.XSetWMProtocols(os.display, os.window, &wm_delete, 1);
        if (success < 0) return error.Unexpected;

        success = c.XMapWindow(os.display, os.window);
        if (success < 0) return error.Unexpected;

        success = c.XStoreName(os.display, os.window, "GrooveStomp's Chip-8 Emulator v2");
        if (success < 0) return error.Unexpected;
    }

    pub fn deinit(os: *Os, alloc: *std.mem.Allocator) void {
        _ = c.glXMakeCurrent(os.display, c.None, null);
        _ = c.glXDestroyContext(os.display, os.gl_device_ctx);
        _ = c.XDestroyWindow(os.display, os.window);
        _ = c.XCloseDisplay(os.display);

        alloc.free(os.texture);
        alloc.destroy(os);
    }

    pub fn initGl(self: *Os) void {
        self.gl_device_ctx = c.glXCreateContext(self.display, self.visual_info, null, c.GL_TRUE);
        var changed = c.glXMakeCurrent(self.display, self.window, self.gl_device_ctx);
        if (changed == 0) {
            std.debug.warn("Couldn't make context current\n", .{});
        }

        var x_window_atts: c.XWindowAttributes = undefined;
        var rc = c.XGetWindowAttributes(self.display, self.window, &x_window_atts);
        if (rc == 0) {
            std.debug.warn("Couldn't get window attributes\n", .{});
        }
        c.glViewport(0, 0, x_window_atts.width, x_window_atts.height);

        self.gl_swap_interval = c.glXGetProcAddress("glXSwapIntervalEXT");

        if (self.gl_swap_interval) |func| {
            @ptrCast(fn(display: ?*c.Display, drawable: c.Drawable, interval: i32)void, func)(self.display, self.window, 0);
        } else {
            std.debug.warn("Couldn't setup gl_swap_interval, so framerate is capped to monitor's refresh rate\n", .{});
        }

        c.glClearColor(0.0, 0.0, 0.0, 1.0);

        c.glEnable(c.GL_TEXTURE_2D);
        c.glGenTextures(1, &self.gl_buffer);
        c.glBindTexture(c.GL_TEXTURE_2D, self.gl_buffer);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexEnvf(c.GL_TEXTURE_ENV, c.GL_TEXTURE_ENV_MODE, c.GL_DECAL);
        var tx_ptr = @ptrCast(?*const c_void, &self.texture[0]);
        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intCast(c_int, self.texture_width), @intCast(c_int, self.texture_height), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, tx_ptr);
    }

    pub fn processEvent(self: *Os, ev: *event.Event) void {
        switch (ev.type) {
            c.Expose => {
                var atts: c.XWindowAttributes = undefined;
                _ = c.XGetWindowAttributes(self.display, self.window, &atts);
                self.window_atts.window_width = @intCast(u32, atts.width);
                self.window_atts.window_height = @intCast(u32, atts.height);
                self.window_atts.updateViewport();
                c.glClear(c.GL_COLOR_BUFFER_BIT);
            },
            c.ConfigureNotify => {
                var xev = ev.xconfigure;
                self.window_atts.window_width = @intCast(u32, xev.width);
                self.window_atts.window_height = @intCast(u32, xev.height);
            },
            c.FocusIn => {
                self.has_input_focus = true;
            },
            c.FocusOut => {
                self.has_input_focus = false;
            },
            c.ClientMessage => {
                // X-atom is inactive?
            },
            else => {
            },
        }
    }

    pub fn eventPending(self: *Os) bool {
        return c.XPending(self.display) != 0;
    }

    pub fn nextEvent(self: *Os) event.Event {
        var ev: event.Event = undefined;
        _ = c.XNextEvent(self.display, @ptrCast(*c.XEvent, &ev));
        return ev;
    }

    pub fn present(self: *Os) void {
        c.glViewport(
            @intCast(c_int, self.window_atts.view_x),
            @intCast(c_int, self.window_atts.view_y),
            @intCast(c_int, self.window_atts.view_width),
            @intCast(c_int, self.window_atts.view_height),
        );

        c.glTexSubImage2D(
            c.GL_TEXTURE_2D,
            0, 0, 0,
            @intCast(c_int, self.texture_width),
            @intCast(c_int, self.texture_height),
            c.GL_RGBA,
            c.GL_UNSIGNED_BYTE,
            @ptrCast(?*const c_void, &self.texture[0]),
        );

        c.glBegin(c.GL_QUADS);
            c.glTexCoord2f(0.0, 1.0); c.glVertex3f(-1.0 + (self.window_atts.sub_pixel_offset_x), -1.0 + (self.window_atts.sub_pixel_offset_y), 0.0);
            c.glTexCoord2f(0.0, 0.0); c.glVertex3f(-1.0 + (self.window_atts.sub_pixel_offset_x),  1.0 + (self.window_atts.sub_pixel_offset_y), 0.0);
            c.glTexCoord2f(1.0, 0.0); c.glVertex3f( 1.0 + (self.window_atts.sub_pixel_offset_x),  1.0 + (self.window_atts.sub_pixel_offset_y), 0.0);
            c.glTexCoord2f(1.0, 1.0); c.glVertex3f( 1.0 + (self.window_atts.sub_pixel_offset_x), -1.0 + (self.window_atts.sub_pixel_offset_y), 0.0);
        c.glEnd();

        c.glXSwapBuffers(self.display, self.window);
    }

    pub fn putPixel(os: *Os, x: usize, y: usize, pixel: Pixel) void {
        if (x < 0 or x >= os.texture_width or y < 0 or y >= os.texture_height) {
            return;
        }

        os.texture[y * os.texture_width + x] = pixel.int;
    }
};
