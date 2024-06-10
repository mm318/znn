const std = @import("std");

const DiagIdx = @import("../../util/diag_idx_to_coords.zig");

pub const Neuron = struct {
    id: struct { layer: usize, neuron: usize },
    coords: struct { x: usize, y: usize },

    fn init(self: *Neuron, layer_id: usize, neuron_id: usize) void {
        self.id.layer = layer_id;
        self.id.neuron = neuron_id;
    }

    fn setCoords(self: *Neuron, x: usize, y: usize) void {
        self.coords.x = x;
        self.coords.y = y;
    }
};

const NeuralNetwork = @This();

layers: [][]Neuron,

fn NeuralNetworkInternalType(comptime num_layers: usize, comptime num_neurons: []const usize) type {
    std.debug.assert(num_neurons.len == num_layers);

    var fields: [num_layers + 1]std.builtin.Type.StructField = undefined;

    fields[0] = .{
        .name = "layers",
        .type = [num_layers][]Neuron,
        .default_value = null,
        .is_comptime = false,
        .alignment = 0,
    };

    inline for (0..num_layers) |i| {
        const field_name = std.fmt.comptimePrint("layer{}", .{i});
        fields[i + 1] = .{
            .name = field_name,
            .type = [num_neurons[i]]Neuron,
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };
    }

    return @Type(.{ .Struct = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &[_]std.builtin.Type.Declaration{},
        .is_tuple = false,
    } });
}

fn NeuralNetworkType(comptime num_layers: usize, comptime num_neurons: []const usize) type {
    return struct {
        const Self = @This();

        internals: NeuralNetworkInternalType(num_layers, num_neurons),
        interface: NeuralNetwork,

        pub fn new() Self {
            var nn = Self{ .internals = undefined, .interface = undefined };
            inline for (0..num_layers) |i| {
                const field_name = std.fmt.comptimePrint("layer{}", .{i});
                nn.internals.layers[i] = &@field(nn.internals, field_name);

                const grid_dim: usize = @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(num_neurons[i])))));
                inline for (0..num_neurons[i]) |j| {
                    nn.internals.layers[i][j].init(i, j);

                    const coords = DiagIdx.coords_from_index(j, grid_dim);
                    nn.internals.layers[i][j].setCoords(coords[0], coords[1]);
                }
            }
            nn.interface.layers = &nn.internals.layers;
            return nn;
        }
    };
}

pub fn new(comptime num_layers: usize, comptime num_neurons: []const usize) NeuralNetworkType(num_layers, num_neurons) {
    return NeuralNetworkType(num_layers, num_neurons).new();
}
