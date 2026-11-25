package ECS


create_particle_grid :: proc(world: ^ECS, scene: ^Scene) {
    spacing: f32 = 0.2
    half: f32 = 10 * spacing 


    for x := 0; x < 10; x += 1 {
        for y := 0; y < 10; y += 1 {
            for z := 0; z < 10; z += 1 {
                if entity, ok := create_entity(world, position = {f32(x) * spacing - half, f32(y) * spacing - half, f32(z) * spacing - half}); ok {
                    add_tag(world, entity, .Particle)
                    append(&scene.sdf, entity)
                }
            }
        }
    }
}

