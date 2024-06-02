const std = @import("std");
const zopengl = @import("zopengl");

const gl = zopengl.bindings;

var flag = true;
var xRotated: gl.Float = undefined;
var yRotated: gl.Float = undefined;
var zRotated: gl.Float = undefined;

pub fn init(loader: zopengl.LoaderFn, display_width: gl.Sizei, display_height: gl.Sizei) !void {
    try zopengl.loadCompatProfileExt(loader);
    gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    yRotated = 40;
    reshapeNetwork(display_width, display_height);
}

fn highlightLines(x: gl.Float, y: gl.Float, z: gl.Float, live_transparency_line: gl.Float) void {
    var a: gl.Float = 0;
    while (a <= 0.5) : (a += 0.1) {
        var b: gl.Float = 0;
        while (b <= 0.5) : (b += 0.1) {
            var c: gl.Float = 0;
            while (c <= 0.5) : (c += 0.1) {
                //First Hidden Layer Plane 1
                gl.pointSize(3.0);
                gl.begin(gl.POINTS);
                gl.color4f(1.0, 1.0, 1.0, 0.05);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.4);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.4);
                gl.end();
                gl.begin(gl.LINE_LOOP);
                gl.color4f(1.0, 1.0, 1.0, live_transparency_line);
                gl.vertex3f(x, y, z);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.4);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.4);
                gl.end();

                //First Hidden Layer Plane 4
                if (c < 0.44) {
                    gl.pointSize(3.0);
                    gl.begin(gl.POINTS);
                    gl.vertex3f(x, y, z);
                    gl.vertex3f(0.17 + b, 0.16 + c, 0.44);
                    gl.vertex3f(0.17 + b, 0.16 + c, 0.44);
                    gl.end();
                    gl.begin(gl.LINE_LOOP);
                    gl.color4f(1.0, 1.0, 1.0, live_transparency_line);
                    gl.vertex3f(x, y, z);
                    gl.vertex3f(0.17 + b, 0.16 + c, 0.44);
                    gl.vertex3f(0.17 + b, 0.16 + c, 0.44);
                    gl.end();
                }

                //Second Hidden Layer Plane 1
                gl.pointSize(3.0);
                gl.begin(gl.POINTS);
                gl.color4f(1.0, 1.0, 1.0, 0.05);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.8);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.8);
                gl.end();
                gl.begin(gl.LINE_LOOP);
                gl.color4f(1.0, 1.0, 1.0, live_transparency_line);
                gl.vertex3f(0.1 + b, 0.1 + a, 0.4);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.8);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.8);
                gl.end();

                //output layer
                gl.pointSize(20.0);
                gl.begin(gl.POINTS);
                gl.color4f(0.0, 0.0, 1.0, 1.0);
                gl.vertex3f(0.2, 0.35, 1.2);
                gl.end();
                gl.begin(gl.LINE_LOOP);
                gl.color4f(1.0, 1.0, 1.0, live_transparency_line);
                gl.vertex3f(0.1 + b, 0.1 + a, 0.8);
                gl.vertex3f(0.2, 0.35, 1.2);
                gl.vertex3f(0.2, 0.35, 1.2);
                gl.end();
            }
        }
    }
}

pub fn dislayNetwork(_: gl.Sizei, _: gl.Sizei) void {
    gl.matrixMode(gl.MODELVIEW);
    // clear the drawing buffer.
    gl.clear(gl.COLOR_BUFFER_BIT);
    // clear the identity matrix.
    gl.loadIdentity();
    // traslate the draw by z = -4.0
    // Note this when you decrease z like -8.0 the drawing will looks far , or smaller.
    gl.translatef(-1.0, -0.75, -3.5); // -1.6 for scaling of 2.3
    // Red color used to draw.
    gl.color3f(0.8, 0.2, 0.1);
    gl.rotatef(yRotated, 0.0, 1.0, 0.0);
    gl.scalef(2.0, 2.0, 2.0);

    const dead_transparency_line = 0.08;
    const live_transparency_line = 0.15;
    var a: gl.Float = 0;
    while (a <= 0.5) : (a += 0.1) {
        var b: gl.Float = 0;
        while (b <= 0.5) : (b += 0.1) {
            var c: gl.Float = 0;
            while (c <= 0.5) : (c += 0.1) {
                //Input Layer
                gl.pointSize(15.0);
                gl.begin(gl.POINTS);
                gl.color4f(1.0, 1.0, 1.0, 0.05);
                gl.vertex3f(0.1 + b, 0.1 + a, 0.0);
                gl.end();

                //First Hidden Layer Plane 1
                gl.pointSize(3.0);
                gl.begin(gl.POINTS);
                gl.color4f(1.0, 1.0, 1.0, 0.05);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.4);
                gl.end();
                gl.begin(gl.LINE_LOOP);
                gl.color4f(1.0, 1.0, 1.0, dead_transparency_line);
                gl.vertex3f(0.1 + b, 0.1 + a, 0.0);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.4);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.4);
                gl.end();

                //First Hidden Layer Plane 2
                if (c < 0.47) {
                    gl.pointSize(3.0);
                    gl.begin(gl.POINTS);
                    gl.vertex3f(0.1 + b, 0.1 + a, 0.0);
                    gl.vertex3f(0.13 + b, 0.13 + c, 0.42);
                    gl.end();
                    gl.begin(gl.LINE_LOOP);
                    gl.color4f(1.0, 1.0, 1.0, dead_transparency_line);
                    gl.vertex3f(0.1 + b, 0.1 + a, 0.0);
                    gl.vertex3f(0.13 + b, 0.13 + c, 0.42);
                    gl.vertex3f(0.13 + b, 0.13 + c, 0.42);
                    gl.end();
                }

                //First Hidden Layer Plane 3
                gl.pointSize(3.0);
                gl.begin(gl.POINTS);
                gl.vertex3f(0.1 + b, 0.1 + a, 0.0);
                gl.vertex3f(0.07 + b, 0.07 + c, 0.42);
                gl.vertex3f(0.07 + b, 0.07 + c, 0.42);
                gl.end();
                gl.begin(gl.LINE_LOOP);
                gl.color4f(1.0, 1.0, 1.0, dead_transparency_line);
                gl.vertex3f(0.1 + b, 0.1 + a, 0.0);
                gl.vertex3f(0.07 + b, 0.07 + c, 0.42);
                gl.vertex3f(0.07 + b, 0.07 + c, 0.42);
                gl.end();

                //First Hidden Layer Plane 4
                if (c < 0.44) {
                    gl.pointSize(3.0);
                    gl.begin(gl.POINTS);
                    gl.vertex3f(0.1 + b, 0.1 + a, 0.0);
                    gl.vertex3f(0.17 + b, 0.16 + c, 0.44);
                    gl.vertex3f(0.17 + b, 0.16 + c, 0.44);
                    gl.end();
                    gl.begin(gl.LINE_LOOP);
                    gl.color4f(1.0, 1.0, 1.0, dead_transparency_line);
                    gl.vertex3f(0.1 + b, 0.1 + a, 0.0);
                    gl.vertex3f(0.17 + b, 0.16 + c, 0.44);
                    gl.vertex3f(0.17 + b, 0.16 + c, 0.44);
                    gl.end();
                }

                //Second Hidden Layer Plane 1
                gl.pointSize(3.0);
                gl.begin(gl.POINTS);
                gl.color4f(1.0, 1.0, 1.0, 0.05);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.8);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.8);
                gl.end();
                gl.begin(gl.LINE_LOOP);
                gl.color4f(1.0, 1.0, 1.0, dead_transparency_line);
                gl.vertex3f(0.1 + b, 0.1 + a, 0.4);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.8);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.8);
                gl.end();

                //Second Hidden Layer Plane 2
                if (c < 0.47) {
                    gl.pointSize(3.0);
                    gl.begin(gl.POINTS);
                    gl.vertex3f(0.1 + b, 0.1 + a, 0.42);
                    gl.vertex3f(0.13 + b, 0.13 + c, 0.82);
                    gl.vertex3f(0.13 + b, 0.13 + c, 0.82);
                    gl.end();
                    gl.begin(gl.LINE_LOOP);
                    gl.color4f(1.0, 1.0, 1.0, dead_transparency_line);
                    gl.vertex3f(0.1 + b, 0.1 + a, 0.0);
                    gl.vertex3f(0.13 + b, 0.13 + c, 0.82);
                    gl.vertex3f(0.13 + b, 0.13 + c, 0.82);
                    gl.end();
                }

                //Output Layer
                gl.pointSize(3.0);
                gl.begin(gl.POINTS);
                gl.color4f(1.0, 1.0, 1.0, 0.05);
                gl.vertex3f(0.1 + b, 0.35, 1.2);
                gl.vertex3f(0.1 + b, 0.35, 1.2);
                gl.end();
                gl.begin(gl.LINE_LOOP);
                gl.color4f(1.0, 1.0, 1.0, dead_transparency_line);
                gl.vertex3f(0.1 + b, 0.1 + c, 0.8);
                gl.vertex3f(0.1 + a, 0.35, 1.2);
                gl.vertex3f(0.1 + a, 0.35, 1.2);
                gl.end();
            }
        }
    }

    if (flag) {
        //Inut image '1'
        gl.pointSize(15.0);
        gl.begin(gl.POINTS);
        gl.color4f(0.0, 0.0, 1.0, 1.0);
        gl.vertex3f(0.3, 0.2, 0.0);
        gl.vertex3f(0.3, 0.3, 0.0);
        gl.vertex3f(0.3, 0.4, 0.0);
        gl.vertex3f(0.3, 0.5, 0.0);
        gl.vertex3f(0.3, 0.6, 0.0);
        gl.vertex3f(0.4, 0.5, 0.0);
        gl.vertex3f(0.2, 0.2, 0.0);
        gl.vertex3f(0.3, 0.2, 0.0);
        gl.vertex3f(0.4, 0.2, 0.0);
        gl.end();

        //Highlighting the active neurons
        highlightLines(0.3, 0.2, 0.0, live_transparency_line);
        highlightLines(0.3, 0.3, 0.0, live_transparency_line);
        highlightLines(0.3, 0.4, 0.0, live_transparency_line);
        highlightLines(0.3, 0.5, 0.0, live_transparency_line);
        highlightLines(0.3, 0.6, 0.0, live_transparency_line);
        highlightLines(0.4, 0.5, 0.0, live_transparency_line);
        highlightLines(0.2, 0.2, 0.0, live_transparency_line);
        highlightLines(0.3, 0.2, 0.0, live_transparency_line);
        highlightLines(0.4, 0.2, 0.0, live_transparency_line);
    }

    // Flushing the whole output
    gl.flush();
}

fn gluPerspective(fovy: gl.Double, aspect: gl.Double, near: gl.Double, far: gl.Double) void {
    const half_height = near * std.math.tan(fovy * 0.5 * std.math.pi / 180);
    const half_width = half_height * aspect;
    gl.frustum(-half_width, half_width, -half_height, half_height, near, far);
}

pub fn reshapeNetwork(display_width: gl.Sizei, display_height: gl.Sizei) void {
    // std.log.info("width: {}. height: {}", .{ display_width, display_height });
    if (display_width == 0 or display_height == 0) {
        return; // Nothing is visible then, so return
    }
    gl.matrixMode(gl.PROJECTION); // Set a new projection matrix
    gl.loadIdentity();
    const x: gl.Double = @floatFromInt(display_width);
    const y: gl.Double = @floatFromInt(display_height);
    gluPerspective(40.0, x / y, 0.5, 20.0); // Angle of view:40 degrees
    gl.viewport(0, 0, display_width, display_height); // Use the whole window for rendering
}

pub fn idleNetwork(display_width: gl.Sizei, display_height: gl.Sizei) void {
    yRotated += 0.05;
    dislayNetwork(display_width, display_height);
}
