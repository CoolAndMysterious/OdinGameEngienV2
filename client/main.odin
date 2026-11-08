package main

import "vendor:sdl3"
import r "renderer"
import "core:fmt"
import ecs "ECS"

main :: proc() {

    fmt.print("Starting Game Client")

    planet := ecs.Planet_SDF{ 
        radius = 4000.0, 
    }

}