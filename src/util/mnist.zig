const std = @import("std");

const IMAGES_MAGIC_NUMBER = 2051;
const LABELS_MAGIC_NUMBER = 2049;

pub const ImageList = struct {
    allocator: std.mem.Allocator,
    raw_data: []u8,
    image_dims: struct { rows: usize, cols: usize },
    list: std.ArrayList([]const u8),

    fn new(allocator: std.mem.Allocator, file_contents: []u8) ImageList {
        var self: ImageList = undefined;

        self.allocator = allocator;
        self.raw_data = file_contents;

        const FileStructure = packed struct {
            magic_number: i32,
            num_images: i32,
            num_rows: i32,
            num_cols: i32,
            pixel_data: u8,
        };

        const read_file: *FileStructure = @alignCast(@ptrCast(file_contents));
        if (@import("builtin").cpu.arch.endian() == .little) {
            read_file.magic_number = @byteSwap(read_file.magic_number);
            read_file.num_images = @byteSwap(read_file.num_images);
            read_file.num_rows = @byteSwap(read_file.num_rows);
            read_file.num_cols = @byteSwap(read_file.num_cols);
        }
        std.log.info("magic number: {}", .{read_file.magic_number});
        std.log.info("number of images: {}", .{read_file.num_images});
        std.log.info("number of rows: {}", .{read_file.num_rows});
        std.log.info("number of columns: {}", .{read_file.num_cols});
        std.debug.assert(read_file.magic_number == IMAGES_MAGIC_NUMBER);

        self.image_dims.rows = @intCast(read_file.num_rows);
        self.image_dims.cols = @intCast(read_file.num_cols);
        const image_size: usize = self.image_dims.rows * self.image_dims.cols;
        const pixel_data_ptr = &read_file.pixel_data;

        self.list = std.ArrayList([]const u8).initCapacity(self.allocator, @intCast(read_file.num_images)) catch @panic("oom");
        for (0..@intCast(read_file.num_images)) |i| {
            // self.list.append(read_file.pixels[i * image_size .. (i + 1) * image_size]) catch @panic("oom");
            var pointer: []const u8 = undefined;
            pointer.ptr = @ptrFromInt(@intFromPtr(pixel_data_ptr) + (i * image_size));
            pointer.len = image_size;
            self.list.append(pointer) catch @panic("oom");
        }

        return self;
    }

    pub fn deinit(self: ImageList) void {
        self.allocator.free(self.raw_data);
        self.list.deinit();
    }
};

pub const LabelList = struct {
    allocator: std.mem.Allocator,
    raw_data: []u8,
    list: []const u8,

    fn new(allocator: std.mem.Allocator, file_contents: []u8) LabelList {
        var self: LabelList = undefined;

        self.allocator = allocator;
        self.raw_data = file_contents;

        const FileStructure = packed struct {
            magic_number: i32,
            num_items: i32,
            label_data: u8,
        };

        const read_file: *FileStructure = @alignCast(@ptrCast(file_contents));
        if (@import("builtin").cpu.arch.endian() == .little) {
            read_file.magic_number = @byteSwap(read_file.magic_number);
            read_file.num_items = @byteSwap(read_file.num_items);
        }
        std.log.info("magic number: {}", .{read_file.magic_number});
        std.log.info("number of items: {}", .{read_file.num_items});
        std.debug.assert(read_file.magic_number == LABELS_MAGIC_NUMBER);

        self.list.ptr = @ptrCast(&read_file.label_data);
        self.list.len = @intCast(read_file.num_items);

        return self;
    }

    pub fn deinit(self: LabelList) void {
        self.allocator.free(self.raw_data);
    }
};

pub fn load_images(allocator: std.mem.Allocator, filename: []const u8) ImageList {
    const filepath = std.fs.cwd().realpathAlloc(allocator, filename) catch @panic("oom");
    defer allocator.free(filepath);
    std.log.info("loading images from {s}", .{filepath});
    const file_contents = std.fs.cwd().readFileAlloc(allocator, filename, 134217728) catch @panic("oom");
    return ImageList.new(allocator, file_contents);
}

pub fn load_labels(allocator: std.mem.Allocator, filename: []const u8) LabelList {
    const filepath = std.fs.cwd().realpathAlloc(allocator, filename) catch @panic("oom");
    defer allocator.free(filepath);
    std.log.info("loading labels from {s}", .{filepath});
    const file_contents = std.fs.cwd().readFileAlloc(allocator, filename, 134217728) catch @panic("oom");
    return LabelList.new(allocator, file_contents);
}
