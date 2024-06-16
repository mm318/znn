const std = @import("std");

const zopengl = @import("zopengl");
const gl = zopengl.bindings;

var _top: gl.Double = 0.0;
var _bottom: gl.Double = 0.0;
var _left: gl.Double = 0.0;
var _right: gl.Double = 0.0;
var _zNear: gl.Double = -10.0;
var _zFar: gl.Double = 10.0;

pub fn initView(display_width: gl.Sizei, display_height: gl.Sizei) void {
    Controller.getMatrix();
    reshapeView(display_width, display_height);
}

pub fn reshapeView(display_width: gl.Sizei, display_height: gl.Sizei) void {
    gl.viewport(0, 0, display_width, display_height); // Use the whole window for rendering

    const w: gl.Double = @floatFromInt(display_width);
    const h: gl.Double = @floatFromInt(display_height);
    _top = 1.0;
    _bottom = -1.0;
    _left = -w / h;
    _right = -_left;

    gl.matrixMode(gl.PROJECTION); // Set a new projection matrix
    gl.loadIdentity();
    gl.frustum(_left, _right, _bottom, _top, _zNear, _zFar);

    gl.matrixMode(gl.MODELVIEW);
}

pub const Utils = struct {
    pub fn convertScreenXYtoWorldXYZ(x: gl.Int, y: gl.Int) struct { gl.Double, gl.Double, gl.Double } {
        var viewport: [4]gl.Int = undefined;
        gl.getIntegerv(gl.VIEWPORT, &viewport);

        // Use the ortho projection and viewport information to map from mouse co-ordinates back into world co-ordinates
        var px = @as(gl.Double, @floatFromInt(x - viewport[0])) / @as(gl.Double, @floatFromInt(viewport[2]));
        var py = @as(gl.Double, @floatFromInt(y - viewport[1])) / @as(gl.Double, @floatFromInt(viewport[3]));
        px = _left + px * (_right - _left);
        py = _top + py * (_bottom - _top);

        return .{ px, py, _zNear };
    }
};

// based on glt zpr code
pub const Controller = struct {
    var _mouseX: gl.Int = 0;
    var _mouseY: gl.Int = 0;
    var _mouseLeft: bool = false;
    var _mouseMiddle: bool = false;
    var _mouseRight: bool = false;

    var _dragPosX: gl.Double = 0.0;
    var _dragPosY: gl.Double = 0.0;
    var _dragPosZ: gl.Double = 0.0;

    var _matrix: [16]gl.Double = undefined;
    var _matrixInverse: [16]gl.Double = undefined;
    var zprReferencePoint: [4]gl.Float = [_]gl.Float{0} ** 4;

    pub const Button = enum {
        left,
        middle,
        right,
    };

    pub const ButtonActionEnum = enum {
        click,
        release,
        wheel_motion,
    };

    pub const ButtonAction = union(ButtonActionEnum) {
        click: struct { x: i32, y: i32 },
        release: struct { x: i32, y: i32 },
        wheel_motion: struct { dx: i32, dy: i32 },
    };

    pub fn handleMouseButton(button: Button, action: ButtonAction) void {
        switch (action) {
            .click => |position| {
                _mouseX = position.x;
                _mouseY = position.y;

                switch (button) {
                    .left => _mouseLeft = true,
                    .middle => _mouseMiddle = true,
                    .right => _mouseRight = true,
                }
            },
            .release => |position| {
                _mouseX = position.x;
                _mouseY = position.y;

                switch (button) {
                    .left => _mouseLeft = false,
                    .middle => _mouseMiddle = false,
                    .right => _mouseRight = false,
                }
            },
            .wheel_motion => |delta_position| {
                // mimic a zoom
                zoom(delta_position.dy);
                return;
            },
        }

        pos(&_dragPosX, &_dragPosY, &_dragPosZ, _mouseX, _mouseY);
    }

    pub fn handleMouseMotion(x: i32, y: i32) void {
        const dx = x - _mouseX;
        const dy = y - _mouseY;
        if (dx == 0 and dy == 0) {
            return;
        }

        var changed = false;
        if (_mouseMiddle or (_mouseLeft and _mouseRight)) { // zoom
            zoom(dy);
        } else if (_mouseLeft) { // rotate
            var viewport: [4]gl.Int = undefined;
            gl.getIntegerv(gl.VIEWPORT, &viewport);

            const ax = @as(gl.Double, @floatFromInt(dy));
            const ay = @as(gl.Double, @floatFromInt(dx));
            const az = 0.0;
            const angle = vlen(ax, ay, az) / @as(gl.Double, @floatFromInt(viewport[2] + 1)) * 180.0;

            // Use inverse matrix to determine local axis of rotation
            const bx = _matrixInverse[0] * ax + _matrixInverse[4] * ay + _matrixInverse[8] * az;
            const by = _matrixInverse[1] * ax + _matrixInverse[5] * ay + _matrixInverse[9] * az;
            const bz = _matrixInverse[2] * ax + _matrixInverse[6] * ay + _matrixInverse[10] * az;

            gl.translatef(zprReferencePoint[0], zprReferencePoint[1], zprReferencePoint[2]);
            gl.rotatef(@floatCast(angle), @floatCast(bx), @floatCast(by), @floatCast(bz));
            gl.translatef(-zprReferencePoint[0], -zprReferencePoint[1], -zprReferencePoint[2]);

            changed = true;
        } else if (_mouseRight) { // pan
            var px: gl.Double = undefined;
            var py: gl.Double = undefined;
            var pz: gl.Double = undefined;
            pos(&px, &py, &pz, x, y);

            gl.loadIdentity();
            gl.translatef(@floatCast(px - _dragPosX), @floatCast(py - _dragPosY), @floatCast(pz - _dragPosZ));
            gl.multMatrixd(&_matrix);

            _dragPosX = px;
            _dragPosY = py;
            _dragPosZ = pz;

            changed = true;
        }
        if (changed) {
            getMatrix();
        }

        _mouseX = x;
        _mouseY = y;
    }

    fn zoom(dy: i32) void {
        const s = @exp(@as(gl.Float, @floatFromInt(dy)) * 0.01);

        gl.translatef(zprReferencePoint[0], zprReferencePoint[1], zprReferencePoint[2]);
        gl.scalef(s, s, s);
        gl.translatef(-zprReferencePoint[0], -zprReferencePoint[1], -zprReferencePoint[2]);

        getMatrix();
    }

    //
    // utility functions
    //

    fn vlen(x: anytype, y: anytype, z: anytype) @TypeOf(x, y, z) {
        return @sqrt((x * x) + (y * y) + (z * z));
    }

    fn pos(px: *gl.Double, py: *gl.Double, pz: *gl.Double, x: gl.Int, y: gl.Int) void {
        const coords = Utils.convertScreenXYtoWorldXYZ(x, y);
        px.* = coords[0];
        py.* = coords[1];
        pz.* = coords[2];
    }

    fn getMatrix() void {
        gl.getDoublev(gl.MODELVIEW_MATRIX, &_matrix);
        invertMatrix(_matrix, &_matrixInverse);
    }

    fn invertMatrix(in: [16]gl.Double, out: *[16]gl.Double) void {
        const matrix = struct {
            data: *const [16]gl.Double,
            fn at(self: @This(), comptime r: usize, comptime c: usize) gl.Double {
                return self.data[((c - 1) * 4) + (r - 1)];
            }
        };
        const m = matrix{ .data = &in };

        // Inverse = adjoint / det. (See linear algebra texts.)

        // pre-compute 2x2 dets for last two rows when computing
        // cofactors of first two rows.
        var d12 = (m.at(3, 1) * m.at(4, 2) - m.at(4, 1) * m.at(3, 2));
        var d13 = (m.at(3, 1) * m.at(4, 3) - m.at(4, 1) * m.at(3, 3));
        var d23 = (m.at(3, 2) * m.at(4, 3) - m.at(4, 2) * m.at(3, 3));
        var d24 = (m.at(3, 2) * m.at(4, 4) - m.at(4, 2) * m.at(3, 4));
        var d34 = (m.at(3, 3) * m.at(4, 4) - m.at(4, 3) * m.at(3, 4));
        var d41 = (m.at(3, 4) * m.at(4, 1) - m.at(4, 4) * m.at(3, 1));

        var tmp: [16]gl.Double = undefined;
        tmp[0] = (m.at(2, 2) * d34 - m.at(2, 3) * d24 + m.at(2, 4) * d23);
        tmp[1] = -(m.at(2, 1) * d34 + m.at(2, 3) * d41 + m.at(2, 4) * d13);
        tmp[2] = (m.at(2, 1) * d24 + m.at(2, 2) * d41 + m.at(2, 4) * d12);
        tmp[3] = -(m.at(2, 1) * d23 - m.at(2, 2) * d13 + m.at(2, 3) * d12);

        // Compute determinant as early as possible using these cofactors.
        const det = m.at(1, 1) * tmp[0] + m.at(1, 2) * tmp[1] + m.at(1, 3) * tmp[2] + m.at(1, 4) * tmp[3];

        // Run singularity test.
        if (det == 0.0) {
            std.log.debug("invert_matrix: Warning: Singular matrix.", .{});
            // memcpy(out,_identity,16*sizeof(double)); */
        } else {
            const invDet = 1.0 / det;

            // Compute rest of inverse.
            tmp[0] *= invDet;
            tmp[1] *= invDet;
            tmp[2] *= invDet;
            tmp[3] *= invDet;

            tmp[4] = -(m.at(1, 2) * d34 - m.at(1, 3) * d24 + m.at(1, 4) * d23) * invDet;
            tmp[5] = (m.at(1, 1) * d34 + m.at(1, 3) * d41 + m.at(1, 4) * d13) * invDet;
            tmp[6] = -(m.at(1, 1) * d24 + m.at(1, 2) * d41 + m.at(1, 4) * d12) * invDet;
            tmp[7] = (m.at(1, 1) * d23 - m.at(1, 2) * d13 + m.at(1, 3) * d12) * invDet;

            // Pre-compute 2x2 dets for first two rows when computing
            // cofactors of last two rows.
            d12 = m.at(1, 1) * m.at(2, 2) - m.at(2, 1) * m.at(1, 2);
            d13 = m.at(1, 1) * m.at(2, 3) - m.at(2, 1) * m.at(1, 3);
            d23 = m.at(1, 2) * m.at(2, 3) - m.at(2, 2) * m.at(1, 3);
            d24 = m.at(1, 2) * m.at(2, 4) - m.at(2, 2) * m.at(1, 4);
            d34 = m.at(1, 3) * m.at(2, 4) - m.at(2, 3) * m.at(1, 4);
            d41 = m.at(1, 4) * m.at(2, 1) - m.at(2, 4) * m.at(1, 1);

            tmp[8] = (m.at(4, 2) * d34 - m.at(4, 3) * d24 + m.at(4, 4) * d23) * invDet;
            tmp[9] = -(m.at(4, 1) * d34 + m.at(4, 3) * d41 + m.at(4, 4) * d13) * invDet;
            tmp[10] = (m.at(4, 1) * d24 + m.at(4, 2) * d41 + m.at(4, 4) * d12) * invDet;
            tmp[11] = -(m.at(4, 1) * d23 - m.at(4, 2) * d13 + m.at(4, 3) * d12) * invDet;
            tmp[12] = -(m.at(3, 2) * d34 - m.at(3, 3) * d24 + m.at(3, 4) * d23) * invDet;
            tmp[13] = (m.at(3, 1) * d34 + m.at(3, 3) * d41 + m.at(3, 4) * d13) * invDet;
            tmp[14] = -(m.at(3, 1) * d24 + m.at(3, 2) * d41 + m.at(3, 4) * d12) * invDet;
            tmp[15] = (m.at(3, 1) * d23 - m.at(3, 2) * d13 + m.at(3, 3) * d12) * invDet;

            @memcpy(out, &tmp);
        }
    }
};

pub fn view() void {
    // the Controller handles this
}
