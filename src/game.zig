const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Actions = enum(u2) { Up, Right, Down, Left };

pub const Game = struct {
    alloc: Allocator,
    board: Board,
    pos: Position,

    pub fn n_actions(self: Game) usize {
        _ = self;
        return @typeInfo(Actions).Enum.fields.len;
    }

    pub fn init(alloc: Allocator, s: []const u8) !Game {
        const b = try Board.init(alloc, s);
        const start_index = b.get_start_pos();
        const start_pos = Position.from_index(start_index, b.width);
        return Game{ .alloc = alloc, .board = b, .pos = start_pos };
    }

    pub fn get_pos(self: Game) usize {
        return self.pos.to_index(self.board.width);
    }

    pub fn reset_pos(self: *Game) usize {
        const pos_index = self.board.get_start_pos();
        self.pos = Position.from_index(pos_index, self.board.width);
        return pos_index;
    }

    pub fn step(self: *Game, action: Actions) struct { pos: usize, reward: usize, ok: bool } {
        switch (action) {
            .Up => {
                if (self.pos.y > 0) self.pos.y -= 1;
            },
            .Right => {
                if (self.pos.x < self.board.width - 1) self.pos.x += 1;
            },
            .Down => {
                if (self.pos.y < self.board.height - 1) self.pos.y += 1;
            },
            .Left => {
                if (self.pos.x > 0) self.pos.x -= 1;
            },
        }

        const pos = self.get_pos();
        switch (self.board.b.items[pos]) {
            .Start, .Normal => return .{ .pos = pos, .reward = 0, .ok = true },
            .Hole => return .{ .pos = pos, .reward = 0, .ok = false },
            .Finish => return .{ .pos = pos, .reward = 10, .ok = false },
        }
    }

    const Position = struct {
        x: usize,
        y: usize,

        fn init(x: usize, y: usize) Position {
            return Position{ .x = x, .y = y };
        }

        fn from_index(i: usize, width: usize) Position {
            const x = i % width;
            const y = i / width;
            return Position{ .x = x, .y = y };
        }

        fn to_index(self: Position, width: usize) usize {
            return self.y * width + self.x;
        }
    };

    const Board = struct {
        b: std.ArrayList(Tile),
        width: usize,
        height: usize,

        const Tile = enum {
            Start,
            Normal,
            Hole,
            Finish,
        };

        fn init(alloc: Allocator, input_string: []const u8) !Board {
            var board = std.ArrayList(Tile).init(alloc);

            var width: usize = 0;
            var width_set = false;
            var height: usize = 1;

            for (input_string) |char| {
                const t = switch (char) {
                    'S' => Tile.Start,
                    'H' => Tile.Hole,
                    '.' => Tile.Normal,
                    'F' => Tile.Finish,
                    '\n' => {
                        if (!width_set) width_set = true;
                        height += 1;
                        continue;
                    },
                    // crash when encountering unknown board elements.
                    else => unreachable,
                };

                // count the width of the first row
                if (!width_set) width += 1;
                try board.append(t);
            }
            return Board{
                .b = board,
                .width = width,
                .height = height,
            };
        }

        fn get_start_pos(self: Board) usize {
            for (0.., self.b.items) |i, t| {
                if (t == .Start) return i;
            }
            // There should always be a start.
            unreachable;
        }
    };

    pub fn deinit(self: Game) void {
        self.board.b.deinit();
    }
};

test "test pos to index" {
    const pos = Game.Position.init(0, 3);
    const got = pos.to_index(4);
    try std.testing.expectEqual(12, got);

    const pos2 = Game.Position.init(1, 3);
    const got2 = pos2.to_index(4);
    try std.testing.expectEqual(13, got2);
}

test "test index to pos" {
    const pos = Game.Position.from_index(12, 4);
    try std.testing.expectEqual(0, pos.x);
    try std.testing.expectEqual(3, pos.y);
}

test "test_test" {
    const s =
        \\S...
        \\.H..
        \\..H.
        \\...F
    ;
    const allocator = std.testing.allocator;
    var game = try Game.init(allocator, s);
    defer game.deinit();
    game.pos = Game.Position.from_index(12, game.board.width);

    const r = game.step(.Down);
    const pos = Game.Position.from_index(r.pos, game.board.width);

    try std.testing.expectEqual(3, pos.x);
    try std.testing.expectEqual(3, pos.y);
}

test "test step to finish" {
    const s =
        \\S...
        \\.H..
        \\..H.
        \\...F
    ;
    const allocator = std.testing.allocator;
    var game = try Game.init(allocator, s);
    defer game.deinit();
    _ = game.step(.Down);
    try std.testing.expectEqual(1, game.pos.y);
    _ = game.step(.Down);
    try std.testing.expectEqual(2, game.pos.y);
    _ = game.step(.Down);
    try std.testing.expectEqual(3, game.pos.y);
    try std.testing.expectEqual(0, game.pos.x);
    _ = game.step(.Right);
    try std.testing.expectEqual(1, game.pos.x);
    _ = game.step(.Right);
    try std.testing.expectEqual(2, game.pos.x);
    const r = game.step(.Right);
    try std.testing.expectEqual(3, game.pos.x);
    try std.testing.expectEqual(3, game.pos.y);
    try std.testing.expectEqual(1, r.reward);
    try std.testing.expectEqual(false, r.ok);
}

test "test fall in hole" {
    const s =
        \\S...
        \\.H..
        \\..H.
        \\...F
    ;
    const allocator = std.testing.allocator;
    var game = try Game.init(allocator, s);
    defer game.deinit();
    _ = game.step(.Right);
    try std.testing.expectEqual(1, game.pos.x);
    const r = game.step(.Down);
    try std.testing.expectEqual(1, game.pos.y);
    try std.testing.expectEqual(0, r.reward);
    try std.testing.expectEqual(false, r.ok);
}
