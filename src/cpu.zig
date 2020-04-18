const std = @import("std");
const bus_pkg = @import("bus.zig");
const os_pkg = @import("platform/os.zig");

//-- Address Modes -------------------------------------------------------------

// Get data from the specified address
fn ABS(cpu: *Cpu, opcode: u16) void {
    var low_byte: u16 = @intCast(u16, lowByte(opcode));
    var high_nibble: u16 = @intCast(u16, nibbleAt(opcode, 2));
    var address = (high_nibble << 8) | low_byte;
    cpu.operand = Operand{ .Address = @truncate(u12, address) };
}

// Data is a byte in the opcode
fn BYT(cpu: *Cpu, opcode: u16) void {
    cpu.operand = Operand{ .Immediate = lowByte(opcode) };
}

// Delay Timer Value
fn DTT(cpu: *Cpu, opcode: u16) void {
    cpu.operand = Operand{ .DelayTimer = {} };
}

// Implicit
fn IMP(cpu: *Cpu, opcode: u16) void {
    cpu.operand = Operand{ .None = {} };
}

// Value from Keypress
fn KEY(cpu: *Cpu, opcode: u16) void {
    cpu.operand = Operand{ .Key = {} };
}

// Get data from the specified register at the X position in the opcode
fn RGX(cpu: *Cpu, opcode: u16) void {
    cpu.operand = Operand{ .Register = @intCast(u4, nibbleAt(opcode, 2)) };
}

// Get data from the specified register at the Y position in the opcode
fn RGY(cpu: *Cpu, opcode: u16) void {
    cpu.operand = Operand{ .Register = @intCast(u4, nibbleAt(opcode, 1)) };
}

//-- Opcodes -------------------------------------------------------------------

/// Add to register V and store in V
fn ADD(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        OperandType.Immediate => |dat| dat,
        else => unreachable,
    };

    var reg = nibbleAt(cpu.opcode, 2);
    var sum = @intCast(u16, cpu.v[reg]) + @intCast(u16, data);
    cpu.v[reg] = @intCast(u8, sum & 0x00FF);
}

/// Add to index register I and store in I
fn ADDI(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        else => unreachable,
    };

    cpu.i = cpu.i + data;
}

/// AND X Y
/// X is a register and the value is stored in X
fn AND(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        else => unreachable,
    };

    var reg = nibbleAt(cpu.opcode, 2);
    cpu.v[reg] = cpu.v[reg] & data;
}

/// Call subroutine at address
fn CALL(cpu: *Cpu, opcode: u16) void {
    if (cpu.sp < 15) {
        cpu.stack[cpu.sp] = cpu.pc;
        cpu.sp += 1;
    } else {
        unreachable;
    }

    switch (cpu.operand) {
        // We auto-increment PC by 2 every step, so subtract 2 from addr here.
        OperandType.Address => |addr| cpu.pc = addr - 2,
        else => unreachable,
    }
}

/// Clear the display
fn CLS(cpu: *Cpu, opcode: u16) void {
    var i: u32 = 0;
    while (i < 2048) : (i += 1) {
        cpu.bus.writeVideo(@intCast(u11, i), 0);
    }
}

/// Dxyn - DRW Vx, Vy, nibble
///
/// Display n-byte sprite starting at memory location I at (Vx, Vy), set VF =
/// collision.
///
/// The interpreter reads n bytes from memory, starting at the address stored in
/// I. These bytes are then displayed as sprites on screen at coordinates (Vx,
/// Vy). Sprites are XORed onto the existing screen. If this causes any pixels
/// to be erased, VF is set to 1, otherwise it is set to 0. If the sprite is
/// positioned so part of it is outside the coordinates of the display, it wraps
/// around to the opposite side of the screen. See instruction 8xy3 for more
/// information on XOR, and section 2.4, Display, for more information on the
/// Chip-8 screen and sprites.
///
fn DRW(cpu: *Cpu, opcode: u16) void {
    var x = cpu.v[@intCast(u4, nibbleAt(cpu.opcode, 2))];
    var y = cpu.v[@intCast(u4, nibbleAt(cpu.opcode, 1))];
    var height = nibbleAt(cpu.opcode, 0);

    cpu.v[0xF] = 0;

    var row: u8 = 0;
    while (row < height) : (row += 1) {
        var pixel: u8 = cpu.bus.readMemory(cpu.i + row);
        const masks = [_]u8{ 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01 };

        for (masks) |mask, col| {
            if ((pixel & mask) == 0) {
                continue;
            }

            // Bounds checking (horizontal)
            if ((x + col) < 0 or (x + col) >= 64) {
                continue;
            }

            // Bounds checking (vertical)
            if ((y + row) < 0 or (y + row) >= 32) {
                continue;
            }

            var y_off = (y + @intCast(u16, row)) * 64;
            var x_off = (x + col);

            // Bounds checking
            if (y_off + x_off > 2048 or y_off + x_off < 0) {
                continue;
            }

            var pos = @intCast(u11, y_off + x_off);

            var bit = cpu.bus.readVideo(pos);
            if (bit == 1) {
                cpu.v[0xF] = 1;
            }

            cpu.bus.writeVideo(pos, bit ^ 1);
        }
    }
}

/// Jump to absolute address
fn JP(cpu: *Cpu, opcode: u16) void {
    switch (cpu.operand) {
        // We auto-increment PC by 2 every step, so subtract 2 from addr here.
        OperandType.Address => |addr| cpu.pc = addr - 2,
        else => unreachable,
    }
}

/// Jump to offset of absolute address
/// Jump to location address + V0
fn JPO(cpu: *Cpu, opcode: u16) void {
    switch (cpu.operand) {
        // We auto-increment PC by 2 every step, so subtract 2 from addr here.
        OperandType.Address => |addr| cpu.pc = cpu.v[0] + addr - 2,
        else => unreachable,
    }
}

/// Load value into register
fn LD(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Immediate => |imm| imm,
        OperandType.Register => |reg| cpu.v[reg],
        OperandType.DelayTimer => cpu.timer_delay,
        OperandType.Key => {
            cpu.suspend_state.is_suspended = true;
            cpu.suspend_state.suspend_reason = SuspendReason.WaitForKey;
            cpu.suspend_state.suspend_result = SuspendResult{ .Incomplete = {} };
            cpu.suspend_state.opcode = cpu.opcode;
            return;
        },
        else => unreachable,
    };

    var reg = nibbleAt(opcode, 2);
    cpu.v[reg] = data;
}

/// The value of register I is set to the lower three nibbles of opcode.
fn LDI(cpu: *Cpu, opcode: u16) void {
    switch (cpu.operand) {
        OperandType.Address => |addr| cpu.i = addr,
        else => unreachable,
    }
}

/// Store registers V0 through Vx in memory starting at location I.
fn LDO(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| reg,
        else => unreachable,
    };

    var i: u12 = 0;
    while (i <= data) : (i += 1) {
        cpu.bus.writeMemory(cpu.i + i, cpu.v[i]);
    }
}

/// Load value into delay timer
fn LDDT(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        else => unreachable,
    };

    cpu.timer_delay = data;
}

/// Load value into sound timer
fn LDST(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        else => unreachable,
    };

    cpu.timer_sound = data;
}

/// Set I = location of sprite for digit Vx.
fn LDF(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        else => unreachable,
    };

    cpu.i = cpu.fp + (data * 5);
}

/// Store BCD representation of Vx in memory locations I, I+1, and I+2.
///
/// Binary coded decimal: Stores the binary-coded decimal representation of VX,
/// with the most significant of three digits at the address in I, the middle
/// digit at I plus 1, and the least significant digit at I plus 2. (In other
/// words, take the decimal representation of VX, place the hundreds digit in
/// memory at location in I, the tens digit at location I+1, and the ones digit
/// at location I+2.)
fn LDB(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        else => unreachable,
    };

    var ones = @truncate(u8, data % 10);
    var tens = @truncate(u8, (data / 10) % 10);
    var hundreds = @truncate(u8, (data / 100) % 10);

    cpu.bus.writeMemory(cpu.i, hundreds);
    cpu.bus.writeMemory(cpu.i + 1, tens);
    cpu.bus.writeMemory(cpu.i + 2, ones);
}

/// Set registers v0-vN from memory starting at location I
/// Load registers into memory pointed to by index register
fn LDV(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| reg,
        else => unreachable,
    };

    var i: u12 = 0;
    while (i <= data) : (i += 1) {
        cpu.v[i] = cpu.bus.readMemory(cpu.i + i);
    }
}

/// OR X Y
/// X is a register and the value is stored in X
fn OR(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        else => unreachable,
    };

    var reg = nibbleAt(cpu.opcode, 2);
    cpu.v[reg] = cpu.v[reg] | data;
}

/// Return from a subroutine
fn RET(cpu: *Cpu, opcode: u16) void {
    if (cpu.sp == 0) {
        unreachable;
    }

    cpu.sp -= 1;
    cpu.pc = cpu.stack[cpu.sp];
}

/// Set Vx = low_byte(operand) & random_value
fn RND(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Immediate => |imm| imm,
        else => unreachable,
    };

    var reg = nibbleAt(cpu.opcode, 2);
    var rnd = @floatToInt(u8, os_pkg.rand() * 255.0);
    cpu.v[reg] = data & rnd;
}

/// Skip next instruction if VX == operand
fn SE(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        OperandType.Immediate => |dat| dat,
        else => unreachable,
    };

    var reg = nibbleAt(cpu.opcode, 2);
    if (cpu.v[reg] == data) {
        cpu.pc += 2;
    }
}

/// Arithmetic shift left
fn SHL(cpu: *Cpu, opcode: u16) void {
    var reg = nibbleAt(cpu.opcode, 2);
    var msb = (cpu.v[reg] & 0x80) >> 7;
    cpu.v[0xF] = msb;
    cpu.v[reg] = cpu.v[reg] << 1;
}

/// Arithmetic shift right
fn SHR(cpu: *Cpu, opcode: u16) void {
    var reg = nibbleAt(cpu.opcode, 2);
    var lsb = cpu.v[reg] & 0x1;
    cpu.v[0xF] = lsb;
    cpu.v[reg] = cpu.v[reg] >> 1;
}

/// Skip next instruction if key with the value of Vx is pressed.
/// Checks the keyboard, and if the key corresponding to the value of Vx is
/// currently in the down position, PC is increased by 2.
fn SKP(cpu: *Cpu, opcode: u16) void {
    var reg = nibbleAt(cpu.opcode, 2);
    var key = cpu.v[reg];
    var press = cpu.bus.readInput(@intCast(u4, key));

    if (press != 0) {
        cpu.pc += 2;
    }
}

/// Skip next instruction if key with the value of Vx is not pressed.
/// Checks the keyboard, and if the key corresponding to the value of Vx is
/// currently in the up position, PC is increased by 2.
fn SKNP(cpu: *Cpu, opcode: u16) void {
    var reg = nibbleAt(cpu.opcode, 2);
    var key = cpu.v[reg];
    var press = cpu.bus.readInput(@truncate(u4, key));

    if (press == 0) {
        cpu.pc += 2;
    }
}

/// Skip next instruction if VX != operand
fn SNE(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        OperandType.Immediate => |dat| dat,
        else => unreachable,
    };

    var reg = nibbleAt(cpu.opcode, 2);
    if (cpu.v[reg] != data) {
        cpu.pc += 2;
    }
}

/// SUB X, Y
/// X - Y
/// X is a register and the result is stored in X
/// VF = NOT borrow
fn SUB(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        else => unreachable,
    };

    var reg = nibbleAt(cpu.opcode, 2);

    if (cpu.v[reg] > data) {
        cpu.v[0xF] = 1;
    } else {
        cpu.v[0xF] = 0;
    }

    var sub: i16 = @intCast(i16, cpu.v[reg]) - @intCast(i16, data);
    var usub = @bitCast(u16, sub);
    cpu.v[reg] = @truncate(u8, usub & 0x00FF);
}

/// SUBN X, Y
/// Y - X
/// X is a register and the result is stored in X
/// VF = NOT borrow
fn SUBN(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        else => unreachable,
    };

    var reg = nibbleAt(cpu.opcode, 2);

    if (cpu.v[reg] < data) {
        cpu.v[0xF] = 1;
    } else {
        cpu.v[0xF] = 0;
    }

    var sub: i16 = @intCast(i16, cpu.v[reg]) - @intCast(i16, data);
    cpu.v[reg] = @intCast(u8, sub & 0x00FF);
}

/// Jump to a machine code routine at nnn.
/// This instruction is only used on the old computers on which Chip-8 was
/// originally implemented. It is ignored by modern interpreters.
fn SYS(cpu: *Cpu, opcode: u16) void {
    // nop
}

fn XOR(cpu: *Cpu, opcode: u16) void {
    var data = switch (cpu.operand) {
        OperandType.Register => |reg| cpu.v[reg],
        else => unreachable,
    };

    var reg = nibbleAt(cpu.opcode, 2);
    cpu.v[reg] = cpu.v[reg] ^ data;
}

/// Illegal opcode
fn XXX(cpu: *Cpu, opcode: u16) void {
    // nop
}

//-- Types ---------------------------------------------------------------------

const fontset = [80]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

const Instruction = struct {
    name: []const u8 = undefined,
    operation: fn (*Cpu, u16) void = undefined,
    address_mode: fn (*Cpu, u16) void = undefined,
};

const OperandType = enum {
    None,
    Address,
    DelayTimer,
    Immediate,
    Register,
    Key,
};

const Operand = union(OperandType) {
    None: void,
    Address: u12,
    DelayTimer: void,
    Immediate: u8,
    Register: u4,
    Key: void,

    pub fn debug(op: Operand) void {
        switch (op) {
            Operand.None => std.debug.warn("None", .{}),
            Operand.Address => |addr| std.debug.warn("Address[{X:0>4}]", .{addr}),
            Operand.DelayTimer => std.debug.warn("DelayTimer", .{}),
            Operand.Immediate => |val| std.debug.warn("Immediate[{X:0>2}]", .{val}),
            Operand.Register => |val| std.debug.warn("Register[{X}]", .{val}),
            Operand.Key => std.debug.warn("Key", .{}),
        }
    }
};

pub const SuspendReason = enum {
    None,
    WaitForKey,
};

pub const SuspendResult = union(enum) {
    Incomplete,
    Key: u4,
};

const SuspendState = struct {
    is_suspended: bool = false,
    suspend_reason: SuspendReason = SuspendReason.None,
    suspend_result: SuspendResult = SuspendResult{ .Incomplete = {} },
    opcode: u16 = undefined,
};

pub const Cpu = struct {
    // Connectivity
    bus: *bus_pkg.Bus,

    // Cpu-specific data
    /// general purpose registers
    v: [16]u8 = undefined,
    /// index register
    i: u12 = 0x0000,
    /// program counter
    pc: u12 = 0x0200,
    stack: [16]u12 = undefined,
    /// stack pointer
    sp: u12 = 0x0000,
    /// font pointer
    fp: u12 = 0x0000,

    // Counters
    /// counter
    timer_delay: u8 = 0,
    /// counter
    timer_sound: u8 = 0,

    // Current instruction information
    opcode: u16 = 0x00,
    instruction: Instruction = Instruction{},
    operand: Operand = Operand{ .None = {} },

    suspend_state: SuspendState,

    pub fn init(cpu: *Cpu, bus: *bus_pkg.Bus, alloc: *std.mem.Allocator) void {
        cpu.bus = bus;

        for (fontset) |fbyte, i| {
            cpu.bus.writeMemory(@intCast(u12, i), fbyte);
        }

        for (cpu.v) |*reg| {
            reg.* = 0;
        }

        for (cpu.stack) |*stack| {
            stack.* = 0;
        }

        cpu.i = 0x0000;
        cpu.pc = 0x0200;
        cpu.sp = 0x0000;
        cpu.fp = 0x0000;

        // Counters
        cpu.timer_delay = 0;
        cpu.timer_sound = 0;

        // Current instruction information
        cpu.opcode = 0x00;
        cpu.instruction = Instruction{};
        cpu.operand = Operand{ .None = {} };
    }

    pub fn deinit(cpu: *Cpu, alloc: *std.mem.Allocator) void {
        alloc.destroy(cpu);
    }

    fn fetch(cpu: *Cpu) u16 {
        var high_byte: u16 = undefined;
        var low_byte: u16 = undefined;
        var b = cpu.bus.readMemory(cpu.pc);
        high_byte = @intCast(u16, b);
        b = cpu.bus.readMemory(cpu.pc + 1);
        low_byte = @intCast(u16, b);
        return (high_byte << 8) | low_byte;
    }

    fn execute(cpu: *Cpu, opcode: u16) void {
        cpu.instruction.address_mode(cpu, opcode);
        cpu.instruction.operation(cpu, opcode);
    }

    pub fn tick(cpu: *Cpu) void {
        if (cpu.suspend_state.is_suspended) {
            switch (cpu.suspend_state.suspend_result) {
                SuspendResult.Incomplete => return,
                SuspendResult.Key => |key| {
                    cpu.suspend_state.is_suspended = false;
                    cpu.operand = Operand{ .Immediate = key };
                    var instruction = decode(cpu.suspend_state.opcode);
                    instruction.operation(cpu, cpu.suspend_state.opcode);
                },
            }
        } else {
            cpu.opcode = cpu.fetch();
            cpu.instruction = decode(cpu.opcode);
            cpu.execute(cpu.opcode);
            cpu.pc += 2;
        }
    }

    pub fn debugStep(cpu: *Cpu, execute_first: bool) void {
        const state = struct {
            var initialized: bool = false;
        };

        if (cpu.suspend_state.is_suspended) {
            switch (cpu.suspend_state.suspend_result) {
                SuspendResult.Incomplete => return,
                SuspendResult.Key => |key| {
                    cpu.suspend_state.is_suspended = false;
                    cpu.operand = Operand{ .Immediate = key };
                    var instruction = decode(cpu.suspend_state.opcode);
                    instruction.operation(cpu, cpu.suspend_state.opcode);
                },
            }

            return;
        }

        if (state.initialized or execute_first) {
            cpu.instruction.operation(cpu, cpu.opcode);
            cpu.pc += 2;
        }

        cpu.opcode = cpu.fetch();
        cpu.instruction = decode(cpu.opcode);
        cpu.instruction.address_mode(cpu, cpu.opcode);
        state.initialized = true;
    }

    pub fn tickTimers(cpu: *Cpu) void {
        if (cpu.timer_delay > 0) {
            cpu.timer_delay -= 1;
        }

        if (cpu.timer_sound > 0) {
            cpu.timer_sound -= 1;
        }
    }
};

//-- Private implementation functions ------------------------------------------

fn nibbleAt(halfword: u16, pos: u8) u8 {
    switch (pos) {
        0 => return @intCast(u8, (halfword & 0x000F) >> 0),
        1 => return @intCast(u8, (halfword & 0x00F0) >> 4),
        2 => return @intCast(u8, (halfword & 0x0F00) >> 8),
        3 => return @intCast(u8, (halfword & 0xF000) >> 12),
        else => unreachable,
    }
}

fn lowByte(short: u16) u8 {
    return @intCast(u8, short & 0x00FF);
}

fn decode(opcode: u16) Instruction {
    var nibble = nibbleAt(opcode, 3);
    switch (nibble) {
        0x1 => return Instruction{ .name = "JP", .operation = JP, .address_mode = ABS },
        0x2 => return Instruction{ .name = "CALL", .operation = CALL, .address_mode = ABS },
        0x3 => return Instruction{ .name = "SE", .operation = SE, .address_mode = BYT },
        0x4 => return Instruction{ .name = "SNE", .operation = SNE, .address_mode = BYT },
        0x5 => return Instruction{ .name = "SE", .operation = SE, .address_mode = RGY },
        0x6 => return Instruction{ .name = "LD", .operation = LD, .address_mode = BYT },
        0x7 => return Instruction{ .name = "ADD", .operation = ADD, .address_mode = BYT },
        0x9 => return Instruction{ .name = "SNE", .operation = SNE, .address_mode = RGY },
        0xA => return Instruction{ .name = "LDI", .operation = LDI, .address_mode = ABS },
        0xB => return Instruction{ .name = "JPO", .operation = JPO, .address_mode = ABS },
        0xC => return Instruction{ .name = "RND", .operation = RND, .address_mode = BYT },
        0xD => return Instruction{ .name = "DRW", .operation = DRW, .address_mode = IMP },

        0x0 => {
            var low_byte = lowByte(opcode);
            switch (low_byte) {
                0xE0 => return Instruction{ .name = "CLS", .operation = CLS, .address_mode = IMP },
                0xEE => return Instruction{ .name = "RET", .operation = RET, .address_mode = IMP },
                else => return Instruction{ .name = "SYS", .operation = SYS, .address_mode = ABS },
            }
        },
        0x8 => {
            var low_nibble = nibbleAt(opcode, 0);
            switch (low_nibble) {
                0x00 => return Instruction{ .name = "LD", .operation = LD, .address_mode = RGY },
                0x01 => return Instruction{ .name = "OR", .operation = OR, .address_mode = RGY },
                0x02 => return Instruction{ .name = "AND", .operation = AND, .address_mode = RGY },
                0x03 => return Instruction{ .name = "XOR", .operation = XOR, .address_mode = RGY },
                0x04 => return Instruction{ .name = "ADD", .operation = ADD, .address_mode = RGY },
                0x05 => return Instruction{ .name = "SUB", .operation = SUB, .address_mode = RGY },
                0x06 => return Instruction{ .name = "SHR", .operation = SHR, .address_mode = IMP },
                0x07 => return Instruction{ .name = "SUBN", .operation = SUBN, .address_mode = RGY },
                0x0E => return Instruction{ .name = "SHL", .operation = SHL, .address_mode = IMP },
                else => return Instruction{ .name = "XXX", .operation = XXX, .address_mode = IMP },
            }
        },
        0xE => {
            var low_byte = lowByte(opcode);
            switch (low_byte) {
                0x9E => return Instruction{ .name = "SKP", .operation = SKP, .address_mode = RGX },
                0xA1 => return Instruction{ .name = "SKNP", .operation = SKNP, .address_mode = RGX },
                else => return Instruction{ .name = "XXX", .operation = XXX, .address_mode = IMP },
            }
        },
        0xF => {
            var low_byte = lowByte(opcode);
            switch (low_byte) {
                0x07 => return Instruction{ .name = "LD", .operation = LD, .address_mode = DTT },
                0x0A => return Instruction{ .name = "LD", .operation = LD, .address_mode = KEY },
                0x15 => return Instruction{ .name = "LDDT", .operation = LDDT, .address_mode = RGX },
                0x18 => return Instruction{ .name = "LDST", .operation = LDST, .address_mode = RGX },
                0x1E => return Instruction{ .name = "ADDI", .operation = ADDI, .address_mode = RGX },
                0x29 => return Instruction{ .name = "LDF", .operation = LDF, .address_mode = RGX },
                0x33 => return Instruction{ .name = "LDB", .operation = LDB, .address_mode = RGX },
                0x55 => return Instruction{ .name = "LDO", .operation = LDO, .address_mode = RGX },
                0x65 => return Instruction{ .name = "LDV", .operation = LDV, .address_mode = RGX },
                else => return Instruction{ .name = "XXX", .operation = XXX, .address_mode = IMP },
            }
        },
        else => return Instruction{ .name = "XXX", .operation = XXX, .address_mode = IMP },
    }
}

pub fn disassemble(mem: []const u8, len: usize, show_addr_offset: bool) void {
    var i: u32 = 0;
    while (i < len - 1) : (i += 2) {
        var high_byte: u16 = @intCast(u16, mem[i]);
        var low_byte: u16 = @intCast(u16, mem[i + 1]);
        var opcode: u16 = (high_byte << 8) | low_byte;

        var instruction = decode(opcode);
        if (show_addr_offset) {
            std.debug.warn("{X:0>4} {X:0>4} {} ", .{ i, opcode, instruction.name });
        } else {
            std.debug.warn("{X:0>4} {} ", .{ opcode, instruction.name });
        }

        // Zig doesn't allow doing a switch on a non-comptime value.
        if (instruction.address_mode == ABS) {
            std.debug.warn("ADDR", .{});
        } else if (instruction.address_mode == BYT) {
            std.debug.warn("BYTE", .{});
        } else if (instruction.address_mode == DTT) {
            std.debug.warn("DT", .{});
        } else if (instruction.address_mode == IMP) {
            std.debug.warn("   ", .{});
        } else if (instruction.address_mode == KEY) {
            std.debug.warn("KEY", .{});
        } else if (instruction.address_mode == RGX) {
            std.debug.warn("REGX", .{});
        } else if (instruction.address_mode == RGY) {
            std.debug.warn("REGY", .{});
        }
        std.debug.warn("\n", .{});
    }
}
