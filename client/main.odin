package main

import "core:fmt"
import "renderer"
import ecs "ECS"


main :: proc() {
    // Create renderer
    r: renderer.Renderer
    // Initialize
    if !renderer.Init(&r) {
        return
    }
    defer renderer.Shutdown(&r)

    // Create an empty world.
    world: ecs.ECS
    // Main loop
    for renderer.Is_Running(&r) {
        // Process operating-system and input events.
        renderer.Process_Events(&r)
        // Stop before updating or drawing if a quit event arrived.
        if !renderer.Is_Running(&r) {
            break
        }



        renderer.Draw(&r)
    }
}