const std = @import("std");

const DiagIdx = @import("../../util/diag_idx_to_coords.zig");

pub const NeuronInfo = struct {
    id: struct { layer: usize, neuron: usize },
    coords: struct { x: usize, y: usize },
    active: bool,

    fn init(self: *NeuronInfo, layer_id: usize, neuron_id: usize) void {
        self.id.layer = layer_id;
        self.id.neuron = neuron_id;
    }

    fn setCoords(self: *NeuronInfo, x: usize, y: usize) void {
        self.coords.x = x;
        self.coords.y = y;
    }
};

const NeuralNetwork = @This();

layers: [][]NeuronInfo,

fn LayerType(comptime num_input_neurons: usize, comptime num_neurons: usize) type {
    return struct {
        const FIRE_THRESHOLD = 1.0;
        const LEAK_RATE = 0.3; // linear decay per timestep

        neurons: [num_neurons]NeuronInfo,
        input_weights: [num_neurons]@Vector(num_input_neurons, f32),
        states: @Vector(num_neurons, f32),
        activities: @Vector(num_neurons, f32),
    };
}

fn NeuralNetworkInternalType(comptime num_layers: usize, comptime num_neurons: []const usize) type {
    std.debug.assert(num_neurons.len == num_layers);

    var fields: [num_layers + 1]std.builtin.Type.StructField = undefined;

    fields[0] = .{
        .name = "layers",
        .type = [num_layers][]NeuronInfo,
        .default_value = null,
        .is_comptime = false,
        .alignment = 0,
    };

    inline for (0..num_layers) |i| {
        const field_name = std.fmt.comptimePrint("layer{}", .{i});
        const num_input_neurons = if (i == 0) 0 else num_neurons[i - 1];
        fields[i + 1] = .{
            .name = field_name,
            .type = LayerType(num_input_neurons, num_neurons[i]),
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

        rng_impl: std.Random.DefaultPrng,
        rng: std.Random,
        internals: NeuralNetworkInternalType(num_layers, num_neurons),
        interface: NeuralNetwork,

        pub fn init(nn: *Self, seed: u64) void {
            nn.rng_impl = std.Random.DefaultPrng.init(seed);
            nn.rng = nn.rng_impl.random();

            inline for (0..num_layers) |layer_id| {
                const field_name = std.fmt.comptimePrint("layer{}", .{layer_id});
                const layer = &@field(nn.internals, field_name);

                const grid_dim: usize = @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(num_neurons[layer_id])))));
                inline for (0..num_neurons[layer_id]) |neuron_id| {
                    const coords = DiagIdx.coords_from_index(neuron_id, grid_dim);
                    layer.neurons[neuron_id].init(layer_id, neuron_id);
                    layer.neurons[neuron_id].setCoords(coords[0], coords[1]);

                    for (0..@typeInfo(@TypeOf(layer.input_weights[neuron_id])).Vector.len) |input_neuron_id| {
                        layer.input_weights[neuron_id][input_neuron_id] = nn.rng.float(f32);
                    }

                    layer.states[neuron_id] = 0;

                    layer.activities[neuron_id] = 0;
                }

                nn.internals.layers[layer_id] = &layer.neurons;
            }

            nn.interface.layers = &nn.internals.layers;
        }

        pub fn setInput(self: *Self, image: []const u8, image_dims: struct { rows: usize, cols: usize }) void {
            for (self.internals.layer0.neurons) |neuron| {
                std.debug.assert(neuron.coords.x < image_dims.cols);
                std.debug.assert(neuron.coords.y < image_dims.rows);
                const idx = neuron.coords.y * image_dims.cols + neuron.coords.x;
                // std.log.debug(
                //     "setting input neuron {}, (x = {}, y = {}, image_idx = {})",
                //     .{ neuron.id.neuron, neuron.coords.x, neuron.coords.y, idx },
                // );
                if (image[idx] > 0) {
                    self.internals.layer0.states[neuron.id.neuron] = 1;
                    self.interface.layers[neuron.id.layer][neuron.id.neuron].active = true;
                }
            }
        }
    };
}

pub fn new(
    allocator: std.mem.Allocator,
    comptime num_layers: usize,
    comptime num_neurons: []const usize,
    seed: u64,
) *NeuralNetworkType(num_layers, num_neurons) {
    const nn = allocator.create(NeuralNetworkType(num_layers, num_neurons)) catch @panic("oom");
    nn.init(seed);
    return nn;
}
