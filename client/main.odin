package main

import rl "vendor:raylib"
import r "renderer"
import "core:fmt"
import ecs "ECS"

main :: proc() {

    fmt.print("Starting Game Client")

    rl.InitWindow(1280, 720, "RayLib Engine")
    rl.DisableCursor()
    defer rl.CloseWindow()

    planet := ecs.Planet_SDF{ 
        radius = 4000.0, 
    }


    for !rl.WindowShouldClose(){


        r.RLrender()
    }
}