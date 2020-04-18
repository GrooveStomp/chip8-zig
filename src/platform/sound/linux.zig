const c = @cImport({
    @cInclude("soundio/soundio.h");
});

const std = @import("std");

pub const Sound = struct {
    soundio: *c.SoundIo = undefined,
    device: *c.SoundIoDevice = undefined,
    stream: *c.SoundIoOutStream = undefined,

    pub fn init(sound: *Sound) !void {
        sound.soundio = c.soundio_create() orelse return error.Unexpected;

        try sioErr(c.soundio_connect(sound.soundio));

        c.soundio_flush_events(sound.soundio);

        var dev_index = c.soundio_default_output_device_index(sound.soundio);
        if (dev_index < 0) return error.NoOutputDeviceFound;

        sound.device = c.soundio_get_output_device(sound.soundio, dev_index) orelse return error.OutOfMemory;
        sound.stream = c.soundio_outstream_create(sound.device) orelse return error.OutOfMemory;
        sound.stream.*.format = @intToEnum(c.SoundIoFormat, c.SoundIoFormatFloat32NE);
        sound.stream.*.write_callback = writeCallback;

        try sioErr(c.soundio_outstream_open(sound.stream));
        try sioErr(c.soundio_outstream_start(sound.stream));

        sound.stop();
    }

    pub fn deinit(sound: *Sound, alloc: *std.mem.Allocator) void {
        sound.stop();
        c.soundio_outstream_destroy(sound.stream);
        c.soundio_device_unref(sound.device);
        c.soundio_destroy(sound.soundio);
        alloc.destroy(sound);
    }

    pub fn stop(sound: *Sound) void {
        var err = c.soundio_outstream_pause(sound.stream, true);
        if (err != c.SoundIoErrorNone) {
            std.debug.warn("Unable to stop device: {}\n", .{ c.soundio_strerror(err) });
        }
    }

    pub fn start(sound: *Sound) void {
        var err = c.soundio_outstream_pause(sound.stream, false);
        if (err != c.SoundIoErrorNone) {
            std.debug.warn("Unable to start device: {}\n", .{ c.soundio_strerror(err) });
        }
    }
};

fn sioErr(err: c_int) !void {
    switch (@intToEnum(c.SoundIoError, err)) {
        .None => {},
        .NoMem => return error.NoMem,
        .InitAudioBackend => return error.InitAudioBackend,
        .SystemResources => return error.SystemResources,
        .OpeningDevice => return error.OpeningDevice,
        .NoSuchDevice => return error.NoSuchDevice,
        .Invalid => return error.Invalid,
        .BackendUnavailable => return error.BackendUnavailable,
        .Streaming => return error.Streaming,
        .IncompatibleDevice => return error.IncompatibleDevice,
        .NoSuchClient => return error.NoSuchClient,
        .IncompatibleBackend => return error.IncompatibleBackend,
        .BackendDisconnected => return error.BackendDisconnected,
        .Interrupted => return error.Interrupted,
        .Underflow => return error.Underflow,
        .EncodingString => return error.EncodingString,
        else => return error.Unknown,
    }
}

fn writeCallback(maybe_out: ?[*]c.SoundIoOutStream, frame_count_min: c_int, frame_count_max: c_int) callconv(.C) void {
    const out = @ptrCast(*c.SoundIoOutStream, maybe_out);
    const layout = &out.layout;
    const sample_rate = out.sample_rate;
    const seconds_per_frame = 1.0 / @intToFloat(f32, sample_rate);
    var frames_left = frame_count_max;

    var areas: [*]c.SoundIoChannelArea = undefined;

    while (frames_left > 0) {
        var frame_count = frames_left;

        sioErr(c.soundio_outstream_begin_write(
            maybe_out,
            @ptrCast([*]?[*]c.SoundIoChannelArea, &areas),
            &frame_count,
        )) catch |err| std.debug.panic("Write failed: {}", .{ @errorName(err) });

        if (frame_count == 0) break;

        const pitch = 440.0;
        const radians_per_second = pitch * 2.0 * std.math.pi;

        var frame: c_int = 0;
        while (frame < frame_count) : (frame += 1) {
            const sample = std.math.sin((seconds_offset + @intToFloat(f32, frame) * seconds_per_frame) * radians_per_second);

            var channel: usize = 0;
            while (channel < @intCast(usize, layout.channel_count)) : (channel += 1) {
                const channel_ptr = areas[channel].ptr;
                const sample_ptr = &channel_ptr[@intCast(usize, areas[channel].step * frame)];
                @ptrCast(*f32, @alignCast(@alignOf(f32), sample_ptr)).* = sample;
            }
        }
        var mod = std.math.modf(seconds_offset + seconds_per_frame * @intToFloat(f32, frame_count));
        seconds_offset = mod.ipart;
        seconds_offset += mod.fpart;

        sioErr(c.soundio_outstream_end_write(out)) catch |err| std.debug.panic("End write failed: {}", .{ @errorName(err) });

        frames_left -= frame_count;
    }
}

var seconds_offset: f32 = 0;
