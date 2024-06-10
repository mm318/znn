const std = @import("std");

const SDL = @import("sdl2");
const zopengl = @import("zopengl");

const NeuralNetwork = @import("lib/lib.zig").NeuralNetwork;
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

fn initialOrientiation(win_width: i32, win_height: i32) void {
    const x_initial = @divTrunc(win_width, 2);
    const y_initial = @divTrunc(win_height, 2);

    const trans_x_displacement = -250;
    const trans_y_displacement = -100;
    const trans_x_final = x_initial + trans_x_displacement;
    const trans_y_final = y_initial + trans_y_displacement;
    Visualizer.handleMouseButton(.right, .{ .click = .{ .x = x_initial, .y = y_initial } });
    Visualizer.handleMouseMotion(trans_x_final, trans_y_final);
    Visualizer.handleMouseButton(.right, .{ .release = .{ .x = trans_x_final, .y = trans_y_final } });

    const rot_x_displacement = 500;
    const rot_x_final = x_initial + rot_x_displacement;
    Visualizer.handleMouseButton(.left, .{ .click = .{ .x = x_initial, .y = y_initial } });
    Visualizer.handleMouseMotion(rot_x_final, y_initial);
    Visualizer.handleMouseButton(.left, .{ .release = .{ .x = rot_x_final, .y = y_initial } });

    const rot_y_displacement = 200;
    const rot_y_final = y_initial + rot_y_displacement;
    Visualizer.handleMouseButton(.left, .{ .click = .{ .x = x_initial, .y = y_initial } });
    Visualizer.handleMouseMotion(x_initial, rot_y_final);
    Visualizer.handleMouseButton(.left, .{ .release = .{ .x = x_initial, .y = rot_y_final } });
}

fn display(neural_network: NeuralNetwork) !void {
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
    Visualizer.init(getProcAddress, win_width, win_height, neural_network);
    Visualizer.idleNetwork(win_width, win_height);
    initialOrientiation(win_width, win_height); // set initial tilt

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
                SDL.SDL_MOUSEBUTTONUP, SDL.SDL_MOUSEBUTTONDOWN => {
                    var button: Visualizer.MouseButton = .left;
                    if (ev.button.button == SDL.SDL_BUTTON_MIDDLE) {
                        button = .middle;
                    } else if (ev.button.button == SDL.SDL_BUTTON_RIGHT) {
                        button = .right;
                    }

                    var action: Visualizer.MouseButtonAction = .{ .click = .{ .x = ev.button.x, .y = ev.button.y } };
                    if (ev.button.type == SDL.SDL_MOUSEBUTTONUP) {
                        action = .{ .release = .{ .x = ev.button.x, .y = ev.button.y } };
                    }

                    Visualizer.handleMouseButton(button, action);
                },
                SDL.SDL_MOUSEWHEEL => {
                    Visualizer.handleMouseButton(.middle, .{ .wheel_motion = .{ .dx = ev.wheel.x, .dy = ev.wheel.y } });
                },
                SDL.SDL_MOUSEMOTION => {
                    Visualizer.handleMouseMotion(ev.motion.x, ev.motion.y);
                },
                SDL.SDL_KEYDOWN => {
                    switch (ev.key.keysym.scancode) {
                        SDL.SDL_SCANCODE_1 => {
                            Visualizer.toggleNeuralNetworkActivity();
                        },
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
    const nn = NeuralNetwork.new(4, &.{ 81, 150, 150, 9 });
    const vis_thread = try std.Thread.spawn(.{}, display, .{nn.interface});
    vis_thread.join();
}
