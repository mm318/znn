const std = @import("std");

const zopengl = @import("zopengl");
const gl = zopengl.bindings;

const NeuralNetwork = @import("../lib.zig").NeuralNetwork;
const Camera = @import("camera.zig");

var neural_network: ?NeuralNetwork = null;
var show_activity_flag = false;
var rng_impl: std.Random.DefaultPrng = undefined;
var rng: std.Random = undefined;

pub fn init(loader: zopengl.LoaderFn, display_width: gl.Sizei, display_height: gl.Sizei, nn: NeuralNetwork) void {
    zopengl.loadCompatProfileExt(loader) catch |err| {
        std.log.err("{}", .{err});
        @panic("error loading opengl functions");
    };

    neural_network = nn;
    rng_impl = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    rng = rng_impl.random();

    gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    Camera.initView(display_width, display_height);
}

const x_spacing: gl.Float = 0.1;
const y_spacing: gl.Float = 0.1;
const z_spacing: gl.Float = 0.4;
const dead_line_transparency = 0.08;
const live_line_transparency = 0.15;

fn nodePosition(neuron: NeuralNetwork.Neuron, grid_dim: usize) struct { gl.Float, gl.Float } {
    const x_offset: gl.Float = @as(gl.Float, @floatFromInt(grid_dim - 1)) * x_spacing / 2;
    const y_offset: gl.Float = @as(gl.Float, @floatFromInt(grid_dim - 1)) * y_spacing / 2;
    return .{
        @as(gl.Float, @floatFromInt(neuron.coords.x)) * x_spacing - x_offset,
        @as(gl.Float, @floatFromInt(neuron.coords.y)) * y_spacing - y_offset,
    };
}

fn drawNodes() void {
    gl.color4f(1.0, 1.0, 1.0, 0.05);

    for (0..neural_network.?.layers.len) |layer_id| {
        // std.log.debug("layer {} has {} neurons", .{layer_id, neural_network.?.layers[layer_id].len});

        if (layer_id == 0 or layer_id == neural_network.?.layers.len - 1) {
            gl.pointSize(15.0); // if input or output layer
        } else {
            gl.pointSize(3.0); // if not input or output layer
        }

        const z = @as(gl.Float, @floatFromInt(layer_id)) * z_spacing;
        const layer_grid_dim: usize = @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(neural_network.?.layers[layer_id].len)))));

        gl.begin(gl.POINTS);
        for (0..neural_network.?.layers[layer_id].len) |neuron_id| {
            const neuron = neural_network.?.layers[layer_id][neuron_id];
            std.debug.assert(neuron.id.layer == layer_id);
            std.debug.assert(neuron.id.neuron == neuron_id);
            const pos = nodePosition(neuron, layer_grid_dim);
            gl.vertex3f(pos[0], pos[1], z);
        }
        gl.end();
    }
}

fn drawEdges() void {
    for (1..neural_network.?.layers.len) |dst_layer_id| {
        const src_layer_id = dst_layer_id - 1;
        const src_z = @as(gl.Float, @floatFromInt(src_layer_id)) * z_spacing;
        const dst_z = @as(gl.Float, @floatFromInt(dst_layer_id)) * z_spacing;
        const src_layer_grid_dim: usize = @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(neural_network.?.layers[src_layer_id].len)))));
        const dst_layer_grid_dim: usize = @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(neural_network.?.layers[dst_layer_id].len)))));
        for (0..neural_network.?.layers[src_layer_id].len) |src_neuron_id| {
            const src_neuron = neural_network.?.layers[src_layer_id][src_neuron_id];
            const src_pos = nodePosition(src_neuron, src_layer_grid_dim);
            for (0..neural_network.?.layers[dst_layer_id].len) |dst_neuron_id| {
                const dst_neuron = neural_network.?.layers[dst_layer_id][dst_neuron_id];
                const dst_pos = nodePosition(dst_neuron, dst_layer_grid_dim);

                gl.begin(gl.LINES);
                if (show_activity_flag and rng.float(f32) < 0.05) {
                    gl.color4f(1.0, 0.0, 0.0, live_line_transparency);
                } else {
                    gl.color4f(1.0, 1.0, 1.0, dead_line_transparency);
                }
                gl.vertex3f(src_pos[0], src_pos[1], src_z);
                gl.vertex3f(dst_pos[0], dst_pos[1], dst_z);
                gl.end();
            }
        }
    }
}

pub fn dislayNetwork(_: gl.Sizei, _: gl.Sizei) void {
    // clear the drawing buffer.
    gl.clear(gl.COLOR_BUFFER_BIT);

    drawNodes();
    drawEdges();

    // Flushing the whole output
    gl.flush();
}

pub fn reshapeNetwork(display_width: gl.Sizei, display_height: gl.Sizei) void {
    // std.log.info("width: {}. height: {}", .{ display_width, display_height });
    if (display_width == 0 or display_height == 0) {
        return; // Nothing is visible then, so return
    }
    Camera.reshapeView(display_width, display_height);
}

pub fn idleNetwork(display_width: gl.Sizei, display_height: gl.Sizei) void {
    dislayNetwork(display_width, display_height);
    Camera.view();
}

pub const MouseButton = Camera.Controller.Button;
pub const MouseButtonAction = Camera.Controller.ButtonAction;

pub fn handleMouseMotion(x: i32, y: i32) void {
    Camera.Controller.handleMouseMotion(x, y);
}

pub fn handleMouseButton(button: MouseButton, action: MouseButtonAction) void {
    Camera.Controller.handleMouseButton(button, action);
}

pub fn toggleNeuralNetworkActivity() void {
    show_activity_flag = !show_activity_flag;
}
