// TODO:
//   - validate input board having a start and a finish

const std = @import("std");
const Game = @import("game.zig").Game;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const s =
        \\S...
        \\.H..
        \\..H.
        \\...F
    ;

    const game = try Game.init(allocator, s);
    defer game.deinit();
    // use this to determine the 'depth' of a q_table
    std.debug.print("Actions: {d}", .{@typeInfo(Game.Action).Enum.fields.len});
}
