const std = @import("std");

const zopengl = @import("zopengl");
const gl = zopengl.bindings;

const Camera = @import("camera.zig");
const Text = @import("text.zig");
const NeuralNetwork = @import("../lib.zig").NeuralNetwork;
const C = struct {
    usingnamespace @import("color.zig");
};

var neural_network: *const NeuralNetwork = undefined;
var show_activity_flag = false;

pub fn init(loader: zopengl.LoaderFn, display_width: gl.Sizei, display_height: gl.Sizei, nn: *const NeuralNetwork) void {
    zopengl.loadCompatProfileExt(loader) catch |err| {
        std.log.err("{}", .{err});
        @panic("error loading opengl functions");
    };

    neural_network = nn;

    // gl.disable(gl.CULL_FACE);
    gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
    gl.clearColor(C.black.r, C.black.g, C.black.b, 0.0);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    Camera.initView(display_width, display_height);
}

const x_spacing: gl.Float = 0.1;
const y_spacing: gl.Float = 0.1;
const z_spacing: gl.Float = 1.6;
const dead_line_transparency = 0.01;
const live_line_transparency = 0.05;

fn nodePosition(neuron: NeuralNetwork.NeuronInfo, grid_dim: usize) struct { gl.Float, gl.Float } {
    const x_offset: gl.Float = @as(gl.Float, @floatFromInt(grid_dim - 1)) * x_spacing / 2;
    const y_offset: gl.Float = @as(gl.Float, @floatFromInt(grid_dim - 1)) * y_spacing / 2;
    return .{
        @as(gl.Float, @floatFromInt(neuron.coords.x)) * x_spacing - x_offset,
        @as(gl.Float, @floatFromInt(neuron.coords.y)) * y_spacing - y_offset,
    };
}

fn drawNodes() void {
    for (0..neural_network.layers.len) |layer_id| {
        // std.log.debug("layer {} has {} neurons", .{layer_id, neural_network.layers[layer_id].len});

        if (layer_id == 0 or layer_id == neural_network.layers.len - 1) {
            gl.pointSize(15.0); // if input or output layer
        } else {
            gl.pointSize(7.0); // if not input or output layer
        }

        const z = @as(gl.Float, @floatFromInt(layer_id)) * z_spacing;
        const layer_grid_dim: usize = @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(neural_network.layers[layer_id].len)))));

        gl.begin(gl.POINTS);
        for (0..neural_network.layers[layer_id].len) |neuron_id| {
            const neuron = neural_network.layers[layer_id][neuron_id];
            std.debug.assert(neuron.id.layer == layer_id);
            std.debug.assert(neuron.id.neuron == neuron_id);

            const neuron_state = neuron.internal_state.load(.monotonic);
            if (neuron_state > 0) {
                gl.color4f(C.blue.r, C.blue.g, C.blue.b, neuron_state);
            } else {
                gl.color4f(C.gray.r, C.gray.g, C.gray.b, 0.15);
            }

            const pos = nodePosition(neuron, layer_grid_dim);
            gl.vertex3f(pos[0], pos[1], z);
        }
        gl.end();
    }
}

fn drawEdges() void {
    if (!show_activity_flag) {
        return;
    }

    for (1..neural_network.layers.len) |dst_layer_id| {
        const src_layer_id = dst_layer_id - 1;
        const src_z = @as(gl.Float, @floatFromInt(src_layer_id)) * z_spacing;
        const dst_z = @as(gl.Float, @floatFromInt(dst_layer_id)) * z_spacing;
        const src_layer_grid_dim: usize = @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(neural_network.layers[src_layer_id].len)))));
        const dst_layer_grid_dim: usize = @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(neural_network.layers[dst_layer_id].len)))));
        for (0..neural_network.layers[src_layer_id].len) |src_neuron_id| {
            const src_neuron = neural_network.layers[src_layer_id][src_neuron_id];
            const src_pos = nodePosition(src_neuron, src_layer_grid_dim);
            for (0..neural_network.layers[dst_layer_id].len) |dst_neuron_id| {
                const dst_neuron = neural_network.layers[dst_layer_id][dst_neuron_id];
                const dst_pos = nodePosition(dst_neuron, dst_layer_grid_dim);

                if (dst_neuron.input_states[src_neuron_id].load(.monotonic) == .FIRING) {
                    gl.begin(gl.LINES);
                    gl.color4f(C.white.r, C.white.g, C.white.b, live_line_transparency);
                    gl.vertex3f(src_pos[0], src_pos[1], src_z);
                    gl.vertex3f(dst_pos[0], dst_pos[1], dst_z);
                    gl.end();
                }
            }
        }
    }
}

fn drawHudInfo(display_width: gl.Sizei, display_height: gl.Sizei) void {
    // clear the depth buffer.
    // gl.clear(gl.DEPTH_BUFFER_BIT);

    // enable 2d render mode
    gl.matrixMode(gl.MODELVIEW);
    gl.pushMatrix();
    defer {
        gl.matrixMode(gl.MODELVIEW);
        gl.popMatrix();
    }
    gl.loadIdentity();

    // continue enabling 2d render mode
    gl.matrixMode(gl.PROJECTION);
    gl.pushMatrix();
    defer {
        gl.matrixMode(gl.PROJECTION);
        gl.popMatrix();
    }
    gl.loadIdentity();
    gl.ortho(0.0, @floatFromInt(display_width), @floatFromInt(display_height), 0.0, -1.0, 10.0);

    // render 2d stuff
    var charbuf: [1024]u8 = undefined;
    const info_str = std.fmt.bufPrint(&charbuf,
        \\Timestep: {}
        \\
        \\Press H for help
    , .{neural_network.timestep.load(.monotonic)}) catch @panic("buffer overflow");
    Text.drawText(info_str, 10, 10, 6, 9, 2, C.white);
}

pub fn reshapeNetwork(display_width: gl.Sizei, display_height: gl.Sizei) void {
    // std.log.info("width: {}. height: {}", .{ display_width, display_height });
    if (display_width == 0 or display_height == 0) {
        return; // Nothing is visible then, so return
    }
    Camera.reshapeView(display_width, display_height);
}

pub fn idleNetwork(display_width: gl.Sizei, display_height: gl.Sizei) void {
    Camera.view();

    // clear the drawing buffer.
    gl.clear(gl.COLOR_BUFFER_BIT);

    drawNodes();
    drawEdges();

    // DEBUG: Draw a red x-axis, a green y-axis, and a blue z-axis. Each of the axes are ten units long.
    gl.begin(gl.LINES);
    gl.color3f(C.red.r, C.red.g, C.red.b);
    gl.vertex3f(0, 0, 0);
    gl.vertex3f(10, 0, 0);
    gl.color3f(C.green.r, C.green.g, C.green.b);
    gl.vertex3f(0, 0, 0);
    gl.vertex3f(0, 10, 0);
    gl.color3f(C.blue.r, C.blue.g, C.blue.b);
    gl.vertex3f(0, 0, 0);
    gl.vertex3f(0, 0, 10);
    gl.end();

    drawHudInfo(display_width, display_height);

    // Flushing the whole output
    gl.flush();
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
