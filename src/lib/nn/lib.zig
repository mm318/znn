const std = @import("std");

const DiagIdx = @import("../../util/diag_idx_to_coords.zig");

const INPUT_AMPLIFICATION = 1.2;
const MAX_INITIAL_WEIGHT = 0.05;

pub const FIRE_THRESHOLD = 0.99;
const LEAK_RATE = 0.3; // linear decay per timestep (TODO: make mock exponential)
const LEARN_RATE = 0.001; // the eta constant in hebbian learning formula

const ConnectionState = enum(u8) {
    AT_REST,
    FIRING,
    WEAKENING,
    STRENGTHENING,
    // FIRED_1_STEPS_AGO,
    // FIRED_2_STEPS_AGO,
    // FIRED_3_STEPS_AGO,
};

pub const NeuronInfo = struct {
    id: struct { layer: usize, neuron: usize },
    coords: struct { x: usize, y: usize },
    internal_state: std.atomic.Value(f32), // keep in sync with LayerType.internal_states[neuron_id]. negative means fixed output
    input_states: []std.atomic.Value(ConnectionState),

    fn init(self: *NeuronInfo, layer_id: usize, neuron_id: usize, input_states: []std.atomic.Value(ConnectionState)) void {
        self.id.layer = layer_id;
        self.id.neuron = neuron_id;
        self.internal_state = @TypeOf(self.internal_state).init(0);
        self.input_states = input_states;
    }

    fn setCoords(self: *NeuronInfo, x: usize, y: usize) void {
        self.coords.x = x;
        self.coords.y = y;
    }
};

const NeuralNetwork = @This();

timestep: std.atomic.Value(usize),
layers: [][]NeuronInfo,

fn LayerType(comptime num_input_neurons: usize, comptime num_neurons: usize) type {
    return struct {
        neurons: [num_neurons]NeuronInfo,
        internal_states: @Vector(num_neurons, f32), // keep in sync with NeuronInfo.internal_state
        input_weights: [num_neurons]@Vector(num_input_neurons, f32),
        input_states: [num_neurons][num_input_neurons]std.atomic.Value(ConnectionState),
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
        const layer_field_name = std.fmt.comptimePrint("layer{}", .{i});
        const num_input_neurons = if (i == 0) 0 else num_neurons[i - 1];
        fields[i + 1] = .{
            .name = layer_field_name,
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
    std.debug.assert(num_layers >= 2);

    return struct {
        // this struct has self-referencing pointers, don't freely copy
        const Self = @This();

        rng_impl: std.Random.DefaultPrng,
        rng: std.Random,
        internals: NeuralNetworkInternalType(num_layers, num_neurons),
        interface: NeuralNetwork,

        pub fn init(nn: *Self, seed: u64) void {
            nn.rng_impl = std.Random.DefaultPrng.init(seed);
            nn.rng = nn.rng_impl.random();

            inline for (0..num_layers) |layer_id| {
                const layer_field_name = std.fmt.comptimePrint("layer{}", .{layer_id});
                const layer = &@field(nn.internals, layer_field_name);

                const grid_dim: usize = @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(num_neurons[layer_id])))));
                inline for (0..num_neurons[layer_id]) |neuron_id| {
                    const coords = DiagIdx.coords_from_index(neuron_id, grid_dim);
                    layer.neurons[neuron_id].init(layer_id, neuron_id, &layer.input_states[neuron_id]);
                    layer.neurons[neuron_id].setCoords(coords[0], coords[1]);

                    layer.internal_states[neuron_id] = 0;
                    for (0..@typeInfo(@TypeOf(layer.input_weights[neuron_id])).Vector.len) |input_neuron_id| {
                        layer.input_weights[neuron_id][input_neuron_id] = MAX_INITIAL_WEIGHT * nn.rng.float(f32);
                        layer.input_states[neuron_id][input_neuron_id] = std.atomic.Value(ConnectionState).init(.AT_REST);
                    }
                }

                nn.internals.layers[layer_id] = &layer.neurons;
            }

            nn.interface.timestep = @TypeOf(nn.interface.timestep).init(0);
            nn.interface.layers = &nn.internals.layers;
        }

        fn setState(self: *Self, comptime layer_id: usize, neuron_id: usize, state: f32) void {
            const layer_field_name = std.fmt.comptimePrint("layer{}", .{layer_id});
            const layer = &@field(self.internals, layer_field_name);
            layer.internal_states[neuron_id] = state;
            self.interface.layers[layer_id][neuron_id].internal_state.store(state, .monotonic);
        }

        pub fn setInputs(self: *Self, image: []const u8, image_dims: struct { rows: usize, cols: usize }) void {
            const layer_id = 0;
            for (self.internals.layers[layer_id]) |neuron| {
                std.debug.assert(neuron.coords.x < image_dims.cols);
                std.debug.assert(neuron.coords.y < image_dims.rows);
                const idx = neuron.coords.y * image_dims.cols + neuron.coords.x;
                // std.log.debug(
                //     "setting input neuron {}, (x = {}, y = {}, image_idx = {})",
                //     .{ neuron.id.neuron, neuron.coords.x, neuron.coords.y, idx },
                // );
                if (image[idx] > 0) {
                    const state = INPUT_AMPLIFICATION * @as(f32, @floatFromInt(image[idx])) / std.math.maxInt(@TypeOf(image[idx]));
                    self.setState(layer_id, neuron.id.neuron, state);
                    if (state >= FIRE_THRESHOLD) {
                        for (&self.internals.layer1.neurons) |*dst_neuron| {
                            dst_neuron.input_states[neuron.id.neuron].store(.FIRING, .monotonic);
                        }
                    }
                }
            }
        }

        pub fn setOutputs(self: *Self, label: usize) void {
            const layer_id = num_layers - 1;
            std.debug.assert(label < num_neurons[layer_id]);
            // std.log.debug("label = {}", .{label});
            for (self.internals.layers[layer_id]) |neuron| {
                if (neuron.id.neuron == label) {
                    self.setState(layer_id, neuron.id.neuron, -FIRE_THRESHOLD);
                } else {
                    self.setState(layer_id, neuron.id.neuron, -FIRE_THRESHOLD / 2.0);
                }
            }
        }

        fn NeuralNetworkTemporaryType() type {
            std.debug.assert(num_neurons.len == num_layers);

            var internals_type: type = undefined;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                if (std.mem.eql(u8, field.name, "internals")) {
                    internals_type = field.type;
                }
            }

            var fields: [num_layers - 1]std.builtin.Type.StructField = undefined;
            inline for (1..num_layers) |i| {
                const layer_field_name = std.fmt.comptimePrint("layer{}", .{i});

                var layer_type: type = undefined;
                inline for (@typeInfo(internals_type).Struct.fields) |field| {
                    if (std.mem.eql(u8, field.name, layer_field_name)) {
                        layer_type = field.type;
                    }
                }

                var states_type: type = undefined;
                inline for (@typeInfo(layer_type).Struct.fields) |field| {
                    if (std.mem.eql(u8, field.name, "internal_states")) {
                        states_type = field.type;
                    }
                }

                fields[i - 1] = .{
                    .name = layer_field_name,
                    .type = states_type,
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

        pub fn timestep(self: *Self, learn: bool) void {
            const relaxation_period = true;

            // sum up inputs
            var state_deltas: NeuralNetworkTemporaryType() = undefined;
            inline for (1..num_layers) |dst_layer_id| {
                const src_layer_id = dst_layer_id - 1;
                const src_layer_field_name = std.fmt.comptimePrint("layer{}", .{src_layer_id});
                const src_layer = &@field(self.internals, src_layer_field_name);
                const dst_layer_field_name = std.fmt.comptimePrint("layer{}", .{dst_layer_id});
                const dst_layer = &@field(self.internals, dst_layer_field_name);
                const dst_layer_deltas = &@field(state_deltas, dst_layer_field_name);

                const FIRE_THRESHOLD_VEC: @TypeOf(src_layer.internal_states) = @splat(FIRE_THRESHOLD);
                const SIGNAL_VEC: @TypeOf(src_layer.internal_states) = @splat(1);
                const NO_SIGNAL_VEC: @TypeOf(src_layer.internal_states) = @splat(0);

                for (0..num_neurons[dst_layer_id]) |dst_neuron_id| {
                    const fired = src_layer.internal_states >= FIRE_THRESHOLD_VEC;
                    const signal = @select(f32, fired, SIGNAL_VEC, NO_SIGNAL_VEC);
                    dst_layer_deltas[dst_neuron_id] += @reduce(.Add, dst_layer.input_weights[dst_neuron_id] * signal);
                }
            }

            // leak or relax, then integrate
            var new_states: NeuralNetworkTemporaryType() = undefined;
            inline for (1..num_layers) |layer_id| {
                const layer_field_name = std.fmt.comptimePrint("layer{}", .{layer_id});
                const layer = &@field(self.internals, layer_field_name);
                const layer_deltas = &@field(state_deltas, layer_field_name);
                const layer_new_state = &@field(new_states, layer_field_name);

                const FIRE_THRESHOLD_VEC: @TypeOf(layer.internal_states) = @splat(FIRE_THRESHOLD);
                const MIN_STATE_VEC: @TypeOf(layer.internal_states) = @splat(0);
                const LEAK_RATE_VEC: @TypeOf(layer.internal_states) = @splat(LEAK_RATE);

                layer_new_state.* = @abs(layer.internal_states);
                if (!learn or layer_id < num_layers - 1) {
                    const fired = layer_new_state.* >= FIRE_THRESHOLD_VEC;
                    if (relaxation_period) {
                        layer_new_state.* = @select(f32, fired, MIN_STATE_VEC, layer_new_state.* - LEAK_RATE_VEC + layer_deltas.*);
                    } else {
                        layer_new_state.* = @select(f32, fired, MIN_STATE_VEC, layer_new_state.* - LEAK_RATE_VEC);
                        layer_new_state.* += layer_deltas.*;
                    }
                    layer_new_state.* = @max(layer_new_state.*, MIN_STATE_VEC);
                }
            }

            // optional: learn (adjust weights)
            if (learn) {
                // perform hebbian learning
                // analyze layer_new_state
                inline for (1..num_layers) |dst_layer_id| {
                    const src_layer_id = dst_layer_id - 1;
                    const src_layer_field_name = std.fmt.comptimePrint("layer{}", .{src_layer_id});
                    const src_layer_state = &@field(self.internals, src_layer_field_name).internal_states;
                    const src_layer_new_state = if (src_layer_id == 0) src_layer_state else &@field(new_states, src_layer_field_name);
                    const dst_layer_field_name = std.fmt.comptimePrint("layer{}", .{dst_layer_id});
                    const dst_layer = &@field(self.internals, dst_layer_field_name);
                    const dst_layer_new_state = &@field(new_states, dst_layer_field_name);

                    const presynapse = src_layer_new_state.* >= @as(@TypeOf(src_layer_new_state.*), @splat(FIRE_THRESHOLD));
                    const postsynapse = dst_layer_new_state.* >= @as(@TypeOf(dst_layer_new_state.*), @splat(FIRE_THRESHOLD));

                    for (0..num_neurons[dst_layer_id]) |dst_neuron_id| {
                        for (0..num_neurons[src_layer_id]) |src_neuron_id| {
                            const learn_rate = LEARN_RATE * src_layer_new_state[src_neuron_id] * @abs(dst_layer_new_state[dst_neuron_id]);
                            const learning = learn_rate > 0;
                            if (learning and presynapse[src_neuron_id] and postsynapse[dst_neuron_id]) {
                                dst_layer.input_states[dst_neuron_id][src_neuron_id].store(.STRENGTHENING, .monotonic);
                                dst_layer.input_weights[dst_neuron_id][src_neuron_id] += learn_rate;
                            } else if (learning and presynapse[src_neuron_id] and !postsynapse[dst_neuron_id]) {
                                dst_layer.input_states[dst_neuron_id][src_neuron_id].store(.WEAKENING, .monotonic);
                                dst_layer.input_weights[dst_neuron_id][src_neuron_id] -= learn_rate;
                            } else if (learning and !presynapse[src_neuron_id] and postsynapse[dst_neuron_id]) {
                                dst_layer.input_states[dst_neuron_id][src_neuron_id].store(.WEAKENING, .monotonic);
                                dst_layer.input_weights[dst_neuron_id][src_neuron_id] -= learn_rate;
                            } else if (presynapse[src_neuron_id]) {
                                dst_layer.input_states[dst_neuron_id][src_neuron_id].store(.FIRING, .monotonic);
                            } else {
                                dst_layer.input_states[dst_neuron_id][src_neuron_id].store(.AT_REST, .monotonic);
                            }
                        }
                    }
                }
            }
            inline for (1..num_layers) |layer_id| {
                const layer_field_name = std.fmt.comptimePrint("layer{}", .{layer_id});
                const layer = &@field(self.internals, layer_field_name);
                const layer_new_state = &@field(new_states, layer_field_name);

                if (!learn or layer_id < num_layers - 1) {
                    layer.internal_states = layer_new_state.*;
                }
            }

            // fire (update connection states)
            inline for (1..num_layers) |dst_layer_id| {
                const dst_layer_field_name = std.fmt.comptimePrint("layer{}", .{dst_layer_id});
                const dst_layer = &@field(self.internals, dst_layer_field_name);

                for (0..num_neurons[dst_layer_id]) |dst_neuron_id| {
                    // syncing with NeuronInfo.internal_state with LayerType.internal_states[neuron_id]
                    dst_layer.neurons[dst_neuron_id].internal_state.store(dst_layer.internal_states[dst_neuron_id], .monotonic);

                    if (!learn) {
                        const src_layer_id = dst_layer_id - 1;
                        const src_layer_field_name = std.fmt.comptimePrint("layer{}", .{src_layer_id});
                        const src_layer = &@field(self.internals, src_layer_field_name);

                        for (0..num_neurons[src_layer_id]) |src_neuron_id| {
                            if (src_layer.internal_states[src_neuron_id] >= FIRE_THRESHOLD) {
                                dst_layer.input_states[dst_neuron_id][src_neuron_id].store(.FIRING, .monotonic);
                            } else {
                                dst_layer.input_states[dst_neuron_id][src_neuron_id].store(.AT_REST, .monotonic);
                            }
                        }
                    }
                }
            }

            _ = self.interface.timestep.fetchAdd(1, .monotonic);
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
