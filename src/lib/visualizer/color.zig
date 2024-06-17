const zopengl = @import("zopengl");
const gl = zopengl.bindings;

const Color = @This();

r: gl.Float,
g: gl.Float,
b: gl.Float,

pub const white = Color{ .r = 1.0, .g = 1.0, .b = 1.0 };
pub const gray = Color{ .r = 0.5, .g = 0.5, .b = 0.5 };
pub const black = Color{ .r = 0.0, .g = 0.0, .b = 0.0 };
pub const red = Color{ .r = 1.0, .g = 0.0, .b = 0.0 };
pub const green = Color{ .r = 0.0, .g = 1.0, .b = 0.0 };
pub const blue = Color{ .r = 0.0, .g = 0.0, .b = 1.0 };
