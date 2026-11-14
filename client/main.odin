
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
    world: ecs.World

    // Load a previous save, if one exists.
    if ecs.load_world(&world) {
        fmt.println("Save loaded successfully!")
    } else {
        fmt.println("No save found. Starting new game.")
    }

    // Clean up world storage when exiting.
    defer ecs.shutdown(&world)

    // Main game loop.
    for !rl.WindowShouldClose() {
        r.RLrender()
    }

    // Save the world before exiting.
    if ecs.save_world(&world) {
        fmt.println("World saved successfully!")
    } else {
        fmt.println("Failed to save world!")
    }

    fmt.println("Exiting Game Client")
}
