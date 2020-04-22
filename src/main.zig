const std = @import("std");
const time = std.time;
const alloc = std.heap.page_allocator;

const platform_input_pkg = @import("platform/input.zig");
const platform_sound_pkg = @import("platform/sound.zig");
const os_pkg = @import("platform/os.zig");

const cpu_pkg = @import("cpu.zig");
const mem_pkg = @import("memory.zig");
const bus_pkg = @import("bus.zig");
const input_pkg = @import("input.zig");
const video_pkg = @import("video.zig");

fn hz(f: usize) f32 {
    return (1.0 / @intToFloat(f32, f));
}

fn sToNs(s: f64) f64 {
    return s * 1000000000;
}

fn sToMs(s: f64) f64 {
    return s * 1000;
}

const timer_ns = sToNs(hz(60));
const frame_ns = sToNs(hz(180));
const video_scale = 10;
var debug_enabled = false;
var sound_playing = false;

pub fn main() !u8 {
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len != 2) {
        std.debug.warn("Usage: prog file\n", .{});
        return 1;
    }

    var os = try alloc.create(os_pkg.Os);
    defer os.deinit(alloc);
    try os.init(64, 32, video_scale, alloc);
    os.initGl();

    var platform_input = try alloc.create(platform_input_pkg.Input);
    defer platform_input.deinit(alloc);
    platform_input.init();

    var sound = try alloc.create(platform_sound_pkg.Sound);
    defer sound.deinit(alloc);
    try sound.init();

    var memory = try alloc.create(mem_pkg.Memory);
    defer memory.deinit(alloc);
    memory.init();

    var input = try alloc.create(input_pkg.Input);
    defer input.deinit(alloc);
    input.init();

    var video = try alloc.create(video_pkg.Video);
    defer video.deinit(alloc);
    video.init();

    var bus = try alloc.create(bus_pkg.Bus);
    defer bus.deinit(alloc);
    bus.init(input, memory, video);

    var cpu = try alloc.create(cpu_pkg.Cpu);
    defer cpu.deinit(alloc);
    cpu.init(bus, alloc);

    var fd = try std.os.open(args[1], std.os.O_RDONLY, 0);
    defer std.os.close(fd);
    var stat = try std.os.fstat(fd);
    var mem: []align(4096) u8 = try std.os.mmap(null, @intCast(usize, stat.size), std.os.PROT_READ, std.os.MAP_PRIVATE, fd, 0);
    defer std.os.munmap(mem);

    try bus.loadProgram(mem);
    if (debug_enabled) {
        cpu_pkg.disassemble(memory.memory[0x200..], @intCast(usize, stat.size), true);
    }

    var timer = try std.time.Timer.start();
    var frame_timer = try std.time.Timer.start();

    var running = true;
    while (running) {
        frame_timer.reset();

        for (input.keys) |*key| {
            key.* = 0;
        }

        while (os.eventPending()) {
            var event = os.nextEvent();
            os.processEvent(&event);
            platform_input.processEvent(&event);
        }

        platform_input.update();

        if (platform_input.getKey(platform_input_pkg.Key.KEY_ESC).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_ESC).held) {
            running = false;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_Q).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_Q).held) {
            input.keys[0x1] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_W).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_W).held) {
            input.keys[0x2] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_E).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_E).held) {
            input.keys[0x3] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_R).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_R).held) {
            input.keys[0xC] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_U).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_U).held) {
            input.keys[0x7] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_I).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_I).held) {
            input.keys[0x8] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_O).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_O).held) {
            input.keys[0x9] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_P).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_P).held) {
            input.keys[0xE] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_A).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_A).held) {
            input.keys[0x4] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_S).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_S).held) {
            input.keys[0x5] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_D).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_D).held) {
            input.keys[0x6] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_F).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_F).held) {
            input.keys[0xD] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_J).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_J).held) {
            input.keys[0xA] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_K).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_K).held) {
            input.keys[0x0] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_L).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_L).held) {
            input.keys[0xB] = 1;
        }
        if (platform_input.getKey(platform_input_pkg.Key.KEY_SEMICOLON).pressed or platform_input.getKey(platform_input_pkg.Key.KEY_SEMICOLON).held) {
            input.keys[0xF] = 1;
        }

        if (cpu.suspend_state.is_suspended) {
            if (cpu.suspend_state.suspend_reason == cpu_pkg.SuspendReason.WaitForKey) {
                for (input.keys) |key, i| {
                    if (key == 1) {
                        cpu.suspend_state.suspend_result = cpu_pkg.SuspendResult{ .Key = @truncate(u4, i) };
                        break;
                    }
                }
            }
        }

        if (platform_input.getKey(platform_input_pkg.Key.KEY_BACKSPACE).pressed) {
            debug_enabled = !debug_enabled;
        }

        if (debug_enabled) {
            if (platform_input.getKey(platform_input_pkg.Key.KEY_SPACE).pressed) {
                cpu.debugStep(false);
                cpu.tickTimers();
                debug(os, cpu);
                std.debug.warn("\n", .{});
                dumpKeys(input);
                std.debug.warn("\n", .{});
                dumpMem(0x200, memory.memory[0x200..], @intCast(usize, stat.size));
                //std.debug.warn("\n", .{});
                //dumpMem(0x00, memory.memory[0..], @intCast(usize, stat.size) + 0x200);
            }
        } else {
            cpu.tick();

            if (timer.read() >= @floatToInt(u64, timer_ns)) {
                cpu.tickTimers();
                if (cpu.timer_sound > 0 and !sound_playing) {
                    sound.start();
                    sound_playing = true;
                } else if (cpu.timer_sound <= 0 and sound_playing) {
                    sound.stop();
                    sound_playing = false;
                }
                timer.reset();
            }

            // debug(os, cpu);
            // std.debug.warn("\n", .{});
            // dumpKeys(input);
            // std.debug.warn("\n", .{});
            // dumpMem(0x200, memory.memory[0x200..], @intCast(usize, stat.size));
        }

        var y: u32 = 0;
        while (y < 32) : (y += 1) {
            var x: u32 = 0;
            while (x < 64) : (x += 1) {
                if (video.buffer[y * 64 + x] == 0x0) {
                    os.putPixel(x, y, os_pkg.newPixel(0, 0, 0, 1));
                } else {
                    os.putPixel(x, y, os_pkg.newPixel(1, 1, 1, 1));
                }
            }
        }

        os.present();

        var sleep_time = @floatToInt(i64, frame_ns) - @intCast(i64, frame_timer.read());
        if (sleep_time > 0) {
            time.sleep(@intCast(u64, sleep_time));
        }
    }

    return 0;
}

fn byteToColor(v: u8) os_pkg.Pixel {
    var f = @intToFloat(f32, v);
    var r = f / 255.0;
    return os_pkg.newPixel(r, r, r, 1);
}

fn shortToColor(v: u16) os_pkg.Pixel {
    var f = @intToFloat(f32, v);
    var r = f / 65536.0;
    return os_pkg.newPixel(r, r, r, 1);
}

fn dumpKeys(input: *input_pkg.Input) void {
    std.debug.warn("k00[{X:1}] k04[{X:1}] k08[{X:1}] k12[{X:1}]\n", .{ input.keys[0x0], input.keys[0x4], input.keys[0x8], input.keys[0xC] });
    std.debug.warn("k01[{X:1}] k05[{X:1}] k09[{X:1}] k13[{X:1}]\n", .{ input.keys[0x1], input.keys[0x5], input.keys[0x9], input.keys[0xD] });
    std.debug.warn("k02[{X:1}] k06[{X:1}] k10[{X:1}] k14[{X:1}]\n", .{ input.keys[0x2], input.keys[0x6], input.keys[0xA], input.keys[0xE] });
    std.debug.warn("k03[{X:1}] k07[{X:1}] k11[{X:1}] k15[{X:1}]\n", .{ input.keys[0x3], input.keys[0x7], input.keys[0xB], input.keys[0xF] });
}

fn debug(os: *os_pkg.Os, cpu: *cpu_pkg.Cpu) void {
    var vp: usize = 0;
    while (vp < 16) : (vp += 1) {
        var frac = @intToFloat(f32, vp) / (255.0 / 16.0);
        os.putPixel(0, vp, os_pkg.newPixel(frac, frac, frac, 1.0));
    }

    for (cpu.v) |reg, i| {
        os.putPixel(1, i, byteToColor(reg));
    }

    std.debug.warn("v00[{X:0>2}] v04[{X:0>2}] v08[{X:0>2}] v12[{X:0>2}]\n", .{ cpu.v[0x0], cpu.v[0x4], cpu.v[0x8], cpu.v[0xC] });
    std.debug.warn("v01[{X:0>2}] v05[{X:0>2}] v09[{X:0>2}] v13[{X:0>2}]\n", .{ cpu.v[0x1], cpu.v[0x5], cpu.v[0x9], cpu.v[0xD] });
    std.debug.warn("v02[{X:0>2}] v06[{X:0>2}] v10[{X:0>2}] v14[{X:0>2}]\n", .{ cpu.v[0x2], cpu.v[0x6], cpu.v[0xA], cpu.v[0xE] });
    std.debug.warn("v03[{X:0>2}] v07[{X:0>2}] v11[{X:0>2}] v15[{X:0>2}]\n", .{ cpu.v[0x3], cpu.v[0x7], cpu.v[0xB], cpu.v[0xF] });

    os.putPixel(16, 0, shortToColor(cpu.pc));
    os.putPixel(16, 1, shortToColor(@intCast(u16, cpu.sp)));
    os.putPixel(17, 0, shortToColor(@intCast(u16, cpu.i)));
    os.putPixel(17, 1, shortToColor(@intCast(u16, cpu.fp)));
    os.putPixel(18, 0, byteToColor(cpu.timer_delay));
    os.putPixel(18, 1, byteToColor(cpu.timer_sound));

    std.debug.warn("pc[{X:0>4}] sp[  {X:0>2}]\n", .{ cpu.pc, cpu.sp });
    std.debug.warn(" i[{X:0>4}] fp[{X:0>4}]\n", .{ cpu.i, cpu.fp });
    std.debug.warn(" d[  {X:0>2}]  s[  {X:0>2}]\n", .{ cpu.timer_delay, cpu.timer_sound });

    std.debug.warn("opcode: ", .{});
    var mem: []u8 = alloc.alloc(u8, 2) catch {
        std.debug.warn("\n", .{});
        return;
    };
    mem[0] = @intCast(u8, cpu.opcode >> 8);
    mem[1] = @intCast(u8, (cpu.opcode << 8) >> 8);
    cpu_pkg.disassemble(mem, 2, false);

    std.debug.warn("operand: ", .{});
    cpu.operand.debug();
    std.debug.warn("\n", .{});
}

fn dumpMem(start: u32, mem: []u8, len: usize) void {
    var a: u32 = start;
    var awritten: u32 = 0;
    std.debug.warn("    ", .{});
    while ((a - start) < 64) : (a += 1) {
        awritten += 1;
        if ((a - start) < 32) {
            std.debug.warn("{X:0>2} ", .{a - start});
        } else if ((a - start) < 63) {
            std.debug.warn("---", .{});
        }
        if (awritten % 4 == 0) {
            if ((a - start) < 32) {
                std.debug.warn("  ", .{});
            } else {
                std.debug.warn("--", .{});
            }
        }
        if (awritten % 64 == 0) {
            std.debug.warn("\n", .{});
        } else if (awritten % 32 == 0) {
            std.debug.warn("\n  +-", .{});
        }
    }

    var b: u32 = 0;
    var b2: u32 = (start & 0xFF00) >> 8;
    var i: u32 = 0;
    var written: u32 = 0;
    std.debug.warn("{X:0>2}| ", .{b2});
    while (i < len) : (i += 1) {
        var byte = mem[i];
        written += 1;
        std.debug.warn("{X:0>2} ", .{byte});
        if (written % 4 == 0) {
            std.debug.warn("  ", .{});
        }
        if (written % 32 == 0) {
            b2 += 2;
            written = 0;
            std.debug.warn("\n", .{});
            std.debug.warn("{X:0>2}| ", .{b2});
            b += 1;
        }
    }
    std.debug.warn("\n", .{});
}

test "" {
    meta.refAllDecls(@This());
}
