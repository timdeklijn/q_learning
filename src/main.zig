// TODO:
//   - validate input board having a start and a finish

const std = @import("std");
const Game = @import("game.zig").Game;
const Actions = @import("game.zig").Actions;
const Allocator = std.mem.Allocator;
var rand = std.rand.DefaultPrng.init(42);

const EPSILON = 0.5;
const LEARNING_RATE = 0.1;
const DISCOUNT_FACTOR = 0.95;

const Agent = struct {
    alloc: Allocator,
    n_actions: usize,
    q_table: std.ArrayList(std.ArrayList(f32)),

    fn init(alloc: Allocator, n_actions: usize, width: usize, height: usize) !Agent {
        var q_table = std.ArrayList(std.ArrayList(f32)).init(alloc);
        for (width * height) |_| {
            var actions = std.ArrayList(f32).init(alloc);
            for (0..n_actions) |_| {
                try actions.append(0.0);
            }
            try q_table.append(actions);
        }
        return Agent{ .alloc = alloc, .n_actions = n_actions, .q_table = q_table };
    }

    fn deinit(self: Agent) void {
        for (self.q_table.items) |item| {
            item.deinit();
        }
        self.q_table.deinit();
    }

    fn print_q_values(self: Agent) void {
        for (0..self.q_table.items.len, self.q_table.items) |i, item| {
            std.debug.print("{} {any}\n", .{ i, item.items });
        }
    }

    fn choose_random_action(self: Agent, n: usize) !usize {
        _ = self;
        return @mod(rand.random().int(usize), n);
    }

    fn choose_action(self: Agent, pos: usize) !usize {
        const num = rand.random().float(f32);
        if (num < EPSILON) {
            return self.choose_random_action(self.n_actions);
        } else {
            const q_vals = self.q_table.items[pos].items;

            var max_value = self.q_table.items[pos].items[0];
            var max_indices = std.ArrayList(usize).init(self.alloc);
            defer max_indices.deinit();
            try max_indices.append(0);

            for (q_vals, 0..q_vals.len) |val, i| {
                if (val > max_value) {
                    max_value = val;
                    try max_indices.resize(0);
                    try max_indices.append(i);
                } else if (val == max_value) {
                    try max_indices.append(i);
                }
            }
            if (max_indices.items.len == 1) return max_indices.items[0];
            return self.choose_random_action(max_indices.items.len - 1);
        }
    }

    fn update(self: Agent, pos: usize, new_pos: usize, action: usize, reward: usize) !void {
        const current_value = self.q_table.items[pos].items[action];
        const future_qs = self.q_table.items[new_pos].items;
        var max_future_q = future_qs[0];
        for (future_qs) |val| {
            if (val > max_future_q) {
                max_future_q = val;
            }
        }
        const temp_fiff_target: f32 = @as(f32, @floatFromInt(reward)) + DISCOUNT_FACTOR * max_future_q;
        self.q_table.items[pos].items[action] = (1 - LEARNING_RATE) * current_value + LEARNING_RATE * temp_fiff_target;
    }
};

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

    var game = try Game.init(allocator, s);
    defer game.deinit();

    const n_actions = game.n_actions();
    const agent = try Agent.init(allocator, n_actions, game.board.width, game.board.height);
    defer agent.deinit();

    var pos = game.get_pos();
    for (0..1000) |_| {
        while (true) {
            const action = agent.choose_action(pos) catch unreachable;
            const ret = game.step(@enumFromInt(action));
            try agent.update(pos, ret.pos, action, ret.reward);

            if (!ret.ok) {
                std.debug.print("DEAD\n", .{});
                break;
            }

            pos = ret.pos;
        }
        agent.print_q_values();
        pos = game.reset_pos();
    }
}
