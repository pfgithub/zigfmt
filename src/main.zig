const std = @import("std");

pub fn unwrapPtr(comptime SomeType: type) type {
    const ti = @typeInfo(SomeType);
    const T = if (ti == .Pointer and ti.Pointer.size == .One) SomeType.Child else SomeType;
    return T;
}
pub fn isString(comptime SomeT: type) bool {
    const ti = @typeInfo(SomeT);
    if (ti == .Pointer and ti.Pointer.child == u8 and ti.Pointer.size == .Slice) return true;
    if (ti == .Array and ti.Array.child == u8) return true;
    return false;
}

pub fn fmt(out: var, args: var, comptime depth: usize) @TypeOf(out).Child.Error!void {
    if (depth > 5) {
        try out.writeAll("...");
        return;
    }
    const Args = unwrapPtr(@TypeOf(args));
    if (comptime isString(Args)) return fmt(out, .{args}, depth);
    if (@typeInfo(Args) != .Struct) {
        @compileError("Expected tuple or struct, got " ++ @typeName(Args));
    }

    inline for (@typeInfo(Args).Struct.fields) |field| {
        const arg = @field(args, field.name); // runtime
        const Arg = unwrapPtr(@TypeOf(arg));

        if (comptime isString(unwrapPtr(Arg))) {
            try out.writeAll(@as([]const u8, arg));
            continue;
        }

        const ti = @typeInfo(Arg);
        if ((ti != .Struct and ti != .Enum and ti != .Union) or !@hasDecl(Arg, "formatOverride")) {
            @compileError("For non-strings, use a helper function eg fmt.num or fmt.structt. Expected []const u8/struct/enum/union, got " ++ @typeName(Arg));
        }
        try arg.formatOverride(out, depth + 1);
    }
}

fn getNumReturnType(comptime NumType: type) type {
    const ti = @typeInfo(NumType);
    const F = std.fmt.FormatOptions;
    return struct {
        v: NumType,
        pub fn formatOverride(me: @This(), out: var, comptime depth: usize) !void {
            switch (ti) {
                .Float => try std.fmt.formatFloatDecimal(me.v, F{}, out),
                .Int, .ComptimeInt => try std.fmt.formatInt(me.v, 10, false, F{}, out),
                else => try fmt(out, "[number]", 0),
            }
        }
    };
}
// we can also include options for precision, width, alignment, and fill in a more complicated version of this function
// also for ints: radix, uppercase
pub fn num(number: var) getNumReturnType(@TypeOf(number)) {
    return getNumReturnType(@TypeOf(number)){ .v = number };
}

pub fn warn(args: var) void {
    const held = std.debug.getStderrMutex().acquire();
    defer held.release();
    const stderr = std.debug.getStderrStream();
    noasync fmt(stderr, args, 0) catch return;
}

pub fn main() !void {
    warn(.{"Warn testing!\n"});
    warn(.{ "My number is: ", num(@as(u64, 25)), "\n" });
    warn(.{ "My float is: ", num(@as(f64, 554.32)), "\n" });
    // const max = 25;
    // var load = 0;
    // while (load <= max) : (load += 1) {
    //     warn(.{
    //         "\r[",
    //         repeatString("#", load),
    //         repeatString(" ", max - load),
    //         "] (",
    //         num(load),
    //         " / ",
    //         num(max),
    //         ")",
    //     });
    // }
    // warn("\n");
    //
    // const SomeStruct = struct {
    //     a: []const u8,
    //     b: i64,
    // };

    // somewhere we need to demo printing a hashmap or array
    // also adding custom overrides (comptime)?
    // warn(.{fmt.addOverride(SomeStruct, overridefn)})
}
