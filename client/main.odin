package main

import "core:fmt"
import "renderer"
import ecs "ECS"
import sdl3 "vendor:sdl3"


main :: proc() {

    // Create renderer
    r: renderer.Renderer

    // Initialize
    if !renderer.Init(&r) {
        return
    }

    defer renderer.Shutdown(&r)

    // Main loop
    for renderer.Is_Running(&r) {

        renderer.Update(&r)

        renderer.Draw(&r)
    }
}