const std = @import("std");

const zopengl = @import("zopengl");
const gl = zopengl.bindings;

const Color = @import("color.zig");

// 0+-1-+2
//  | | |
// 3+-4-+5
//  | | |
// 6+-7-+8

const digit_lines = [_][]const u8{
    "", // ' '
    "02288660", // '0'
    "687113", // '1'
    "0225533668", // '2'
    "02288635", // '3'
    "033528", // '4'
    "0203355886", // '5'
    "0206685835", // '6'
    "0226", // '7'
    "0228866035", // '8'
    "02283503", // '9'
    "06022835", // 'A'
    "0206682835", // 'B'
    "200668", // 'C'
    "0115577660", // 'D'
    "02066834", // 'E'
    "020634", // 'F'
    "0206688545", // 'G'
    "062835", // 'H'
    "026817", // 'I'
    "288636", // 'J'
    "062338", // 'K'
    "0668", // 'L'
    "06044228", // 'M'
    "060828", // 'N'
    "02288606", // 'O'
    "06022535", // 'P'
    "0206286848", // 'Q'
    "0206253548", // 'R'
    "0203355868", // 'S'
    "0217", // 'T'
    "066828", // 'U'
    "0772", // 'V'
    "06644882", // 'W'
    "0826", // 'X'
    "470424", // 'Y'
    "022668", // 'Z'
};

fn digitPointX(k: u8) gl.Float {
    return @as(gl.Float, @floatFromInt(k % 3)) * 0.5;
}

fn digitPointY(k: u8) gl.Float {
    return @as(gl.Float, @floatFromInt(k / 3)) * 0.5;
}

fn charIndex(k: u8) usize {
    return switch (k) {
        '0'...'9' => k - '0' + 1,
        'A'...'Z' => k - 'A' + 11,
        'a'...'z' => k - 'a' + 11,
        else => 0,
    };
}

fn drawGlyph(digit: u8, x: gl.Float, y: gl.Float, w: gl.Float, h: gl.Float) void {
    const q = digit_lines[charIndex(digit)];
    var k: usize = 0;
    while (k < q.len) : (k += 2) {
        gl.vertex2f(digitPointX(q[k + 0] - '0') * w + x, digitPointY(q[k + 0] - '0') * h + y);
        gl.vertex2f(digitPointX(q[k + 1] - '0') * w + x, digitPointY(q[k + 1] - '0') * h + y);
    }
}

pub fn drawText(
    text: []const u8,
    x: gl.Float,
    y: gl.Float,
    char_width: gl.Float,
    char_height: gl.Float,
    vertical_spacing: gl.Float,
    horizontal_spacing: gl.Float,
    color: Color,
) void {
    gl.color4f(color.r, color.g, color.b, 1.0);
    var xx = x;
    var yy = y;
    gl.begin(gl.LINES);
    for (text) |char| {
        if (char == '\n') {
            yy += char_height + vertical_spacing;
            xx = x;
        } else {
            drawGlyph(char, xx, yy, char_width, char_height);
            xx += char_width + horizontal_spacing;
        }
    }
    gl.end();
}
