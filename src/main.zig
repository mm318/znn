const std = @import("std");
const SDL = @import("sdl2");
const zopengl = @import("zopengl");

const gl = zopengl.bindings;

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}

fn getProcAddress(name: [:0]const u8) ?*const anyopaque {
    return SDL.SDL_GL_GetProcAddress(name);
}

pub fn main() !void {
    if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO) < 0) {
        sdlPanic();
    }
    defer SDL.SDL_Quit();

    const WIN_WIDTH = 640;
    const WIN_HEIGHT = 480;
    const window = SDL.SDL_CreateWindow(
        "SDL.zig Basic Demo",
        SDL.SDL_WINDOWPOS_CENTERED,
        SDL.SDL_WINDOWPOS_CENTERED,
        WIN_WIDTH,
        WIN_HEIGHT,
        SDL.SDL_WINDOW_OPENGL | SDL.SDL_WINDOW_ALLOW_HIGHDPI | SDL.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
    defer SDL.SDL_DestroyWindow(window);

    const context = SDL.SDL_GL_CreateContext(window) orelse sdlPanic();
    defer SDL.SDL_GL_DeleteContext(context);

    try zopengl.loadCoreProfile(getProcAddress, 4, 0);

    mainLoop: while (true) {
        var ev: SDL.SDL_Event = undefined;
        while (SDL.SDL_PollEvent(&ev) != 0) {
            switch (ev.type) {
                SDL.SDL_QUIT => {
                    break :mainLoop;
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

        gl.viewport(0, 0, WIN_WIDTH, WIN_HEIGHT);
        // gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.2, 0.4, 0.8, 1.0 });
        gl.clearColor(1.0, 1.0, 1.0, 0.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        SDL.SDL_GL_SwapWindow(window);
    }
}
