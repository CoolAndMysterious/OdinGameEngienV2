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
    

    r.RL_Init()
    defer r.RL_Shutdown()
    // Create an empty world.
    world: ecs.ECS

    scene: ecs.Scene
    // Spawn 1000 particles (10x10x10 grid, 10 cm spacing)
    ecs.create_particle_grid(&world, &scene)

    // Main game loop.
    for !rl.WindowShouldClose() {
        r.RLrender(&world, &scene)
    }
    fmt.println("Exiting Game Client")
}
