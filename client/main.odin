package main

import "core:fmt"
import r "renderer"
import ecs "ECS"
import rl "vendor:raylib"

main :: proc() {
    fmt.println("Starting Game Client")

    rl.InitWindow(1280, 720, "RayLib Engine")
    rl.DisableCursor()
    defer rl.CloseWindow()

    // Create an empty world.
    world: ecs.ECS

    // Main game loop.
    for !rl.WindowShouldClose() {
        r.RLrender()
    }
    fmt.println("Exiting Game Client")
}
