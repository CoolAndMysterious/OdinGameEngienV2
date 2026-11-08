package main

import "core:fmt"
import r "renderer"
import ecs "ECS"

main :: proc() {

    fmt.print("Starting Game Client")

    rl.InitWindow(1280, 720, "RayLib Engine")
    rl.DisableCursor()
    defer rl.CloseWindow()

    for !rl.WindowShouldClose(){


        r.RLrender()
    }
}