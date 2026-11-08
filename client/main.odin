package main

import "core:fmt"
import r "renderer"
import ecs "ECS"
import sdl3 "vendor:sdl3"

main :: proc() {
    // Initialize SDL video
    if !sdl3.Init({.VIDEO}) {
        fmt.println("SDL initialization failed:", sdl3.GetError())
        return
    }
    defer sdl3.Quit()

    // Create window
    window := sdl3.CreateWindow(
        "Odin Engine - SDL3",
        1280,
        720,
        {.RESIZABLE},
    )

    if window == nil {
        fmt.println("Window creation failed:", sdl3.GetError())
        return
    }
    defer sdl3.DestroyWindow(window)

    running := true

    for running {
        event: sdl3.Event

        for sdl3.PollEvent(&event) {
            #partial switch event.type {
            case .QUIT:
                running = false

            case:
            // Ignore events we don't currently need.
            }
        }
    }
}