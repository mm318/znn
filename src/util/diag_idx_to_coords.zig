const std = @import("std");

fn triangular(n: anytype) @TypeOf(n) {
    return @divTrunc(n * (n + 1), 2);
}

pub fn coords_from_index(diag_idx: anytype, dim: @TypeOf(diag_idx)) struct { @TypeOf(diag_idx), @TypeOf(diag_idx) } {
    var col: @TypeOf(diag_idx) = undefined;
    var row: @TypeOf(diag_idx) = undefined;
    if (diag_idx < triangular(dim)) {
        const basecol: @TypeOf(diag_idx) = @intFromFloat((@sqrt(@as(f32, @floatFromInt(8 * diag_idx + 1))) - 1) / 2);
        row = diag_idx - triangular(basecol);
        col = basecol - row;
    } else {
        const oldcoords = coords_from_index(dim * dim - 1 - diag_idx, dim);
        const oldcol = oldcoords[0];
        const oldrow = oldcoords[1];
        row = dim - 1 - oldrow;
        col = dim - 1 - oldcol;
    }
    return .{ col, row };
}
