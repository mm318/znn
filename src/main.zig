const std = @import("std");
const SDL = @import("sdl2");
const zopengl = @import("zopengl");
const Visualizer = @import("lib/lib.zig").Visualizer;

const DEFAULT_WIN_WIDTH = 1280;
const DEFAULT_WIN_HEIGHT = 960;

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}

fn getProcAddress(name: [:0]const u8) ?*const anyopaque {
    return SDL.SDL_GL_GetProcAddress(name);
}

fn display() !void {
    if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO) < 0) {
        sdlPanic();
    }
    defer SDL.SDL_Quit();

    const window = SDL.SDL_CreateWindow(
        "Network Visualizer",
        SDL.SDL_WINDOWPOS_CENTERED,
        SDL.SDL_WINDOWPOS_CENTERED,
        DEFAULT_WIN_WIDTH,
        DEFAULT_WIN_HEIGHT,
        SDL.SDL_WINDOW_OPENGL | SDL.SDL_WINDOW_ALLOW_HIGHDPI | SDL.SDL_WINDOW_RESIZABLE | SDL.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
    defer SDL.SDL_DestroyWindow(window);

    // Create an OpenGL context using the SDL windowing system
    const context = SDL.SDL_GL_CreateContext(window) orelse sdlPanic();
    defer SDL.SDL_GL_DeleteContext(context);

    // {
    //     var w: c_int = undefined;
    //     var h: c_int = undefined;
    //     SDL.SDL_GetWindowSize(window, &w, &h);
    //     std.log.info("Window size is {d}x{d}", .{ w, h });
    //     SDL.SDL_GL_GetDrawableSize(window, &w, &h);
    //     std.log.info("Drawable size is {d}x{d}", .{ w, h });
    // }

    var win_width: c_int = undefined;
    var win_height: c_int = undefined;
    SDL.SDL_GetWindowSize(window, &win_width, &win_height);
    try Visualizer.init(getProcAddress, win_width, win_height);

    mainLoop: while (true) {
        var ev: SDL.SDL_Event = undefined;
        while (SDL.SDL_PollEvent(&ev) != 0) {
            switch (ev.type) {
                SDL.SDL_QUIT => {
                    break :mainLoop;
                },
                SDL.SDL_WINDOWEVENT => {
                    switch (ev.window.event) {
                        SDL.SDL_WINDOWEVENT_RESIZED => {
                            win_width = ev.window.data1;
                            win_height = ev.window.data2;
                            Visualizer.reshapeNetwork(win_width, win_height);
                        },
                        else => {},
                    }
                },
                SDL.SDL_KEYDOWN => {
                    switch (ev.key.keysym.scancode) {
                        SDL.SDL_SCANCODE_ESCAPE => {
                            break :mainLoop;
                        },
                        else => {
                            std.log.info("key pressed: {}\n", .{ev.key.keysym.scancode});
                        },
                    }
                },
                else => {},
            }
        }

        Visualizer.idleNetwork(win_width, win_height);

        SDL.SDL_GL_SwapWindow(window);
    }
}

pub fn main() !void {
    const vis_thread = try std.Thread.spawn(.{}, display, .{});
    vis_thread.join();
}
