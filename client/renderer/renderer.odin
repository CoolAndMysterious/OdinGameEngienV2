package renderer

import "core:fmt"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import "core:math"
import ecs "../ECS"

camera := rl.Camera3D{
    position   = {0, 2, 6},
    target     = {0, 1, 0},
    up         = {0, 1, 0},
    fovy       = 60,
    projection = .PERSPECTIVE,
}

// GPU SSBO handle and allocated capacity.
scene_ssbo: u32 = 0
scene_ssbo_capacity: u32 = 0

// Temporary packed upload data: 4 floats per SDF entity.
gpu_positions: [dynamic]f32
sdf_shader: rl.Shader

// Cache shader uniform locations.
sdf_loc_sphere_count: i32
sdf_loc_cam_pos:      i32
sdf_loc_cam_right:    i32
sdf_loc_cam_up:       i32
sdf_loc_cam_forward:  i32
sdf_loc_tan_fov:      i32
sdf_loc_resolution:   i32
sdf_loc_view:         i32
sdf_loc_projection:   i32

RL_Init :: proc() {
    sdf_shader = rl.LoadShader(
        nil,
        cstring("Shared/Shaders/SDF_Raymarcher.fs"),
    )

    if sdf_shader.id == 0 {
        fmt.println("ERROR: SDF shader failed to load")
        return
    }

    // Cache uniform locations.
    sdf_loc_sphere_count = rl.GetShaderLocation( sdf_shader, cstring("sphere_count"), )
    sdf_loc_cam_pos = rl.GetShaderLocation( sdf_shader, cstring("cam_pos"), )
    sdf_loc_cam_right = rl.GetShaderLocation( sdf_shader, cstring("cam_right"), )
    sdf_loc_cam_up = rl.GetShaderLocation( sdf_shader, cstring("cam_up"), )
    sdf_loc_cam_forward = rl.GetShaderLocation( sdf_shader, cstring("cam_forward"), )
    sdf_loc_tan_fov = rl.GetShaderLocation( sdf_shader, cstring("tan_fov"), )
    sdf_loc_resolution = rl.GetShaderLocation( sdf_shader, cstring("resolution"), )
    sdf_loc_view = rl.GetShaderLocation( sdf_shader, cstring("view_matrix"), )
    sdf_loc_projection = rl.GetShaderLocation( sdf_shader, cstring("proj_matrix"), )

    fmt.println("SDF fragment shader loaded successfully")
}

RL_Shutdown :: proc() {
    if scene_ssbo != 0 {
        rlgl.UnloadShaderBuffer(scene_ssbo)
        scene_ssbo = 0
        scene_ssbo_capacity = 0
    }

    if sdf_shader.id != 0 {
        rl.UnloadShader(sdf_shader)
        sdf_shader = {}
    }

    delete(gpu_positions)
}

Draw_SDF :: proc(sphere_count: u32) {
    screen_width := f32(rl.GetScreenWidth())
    screen_height := f32(rl.GetScreenHeight())

    aspect := screen_width / screen_height

    // Read camera data from the existing Raylib camera.
    cam_pos := camera.position
    cam_right := rl.GetCameraRight(&camera)
    cam_forward := rl.GetCameraForward(&camera)

    cam_up := rl.Vector3CrossProduct(cam_right, cam_forward)

    view_matrix := rl.GetCameraViewMatrix(&camera)
    projection_matrix := rl.GetCameraProjectionMatrix( &camera, aspect, )

    // Camera fovy is vertical FOV, in degrees.
    vertical_tan := math.tan(
        camera.fovy * math.PI / 360.0,
    )

    tan_fov := rl.Vector2{
        f32(vertical_tan),
        f32(vertical_tan),
    }

    resolution := rl.Vector2{
        screen_width,
        screen_height,
    }

    // Upload camera uniforms.
    rl.SetShaderValue( sdf_shader, sdf_loc_cam_pos, rawptr(&cam_pos), .VEC3, )
    rl.SetShaderValue( sdf_shader, sdf_loc_cam_right, rawptr(&cam_right), .VEC3, )
    rl.SetShaderValue( sdf_shader, sdf_loc_cam_up, rawptr(&cam_up), .VEC3, )
    rl.SetShaderValue( sdf_shader, sdf_loc_cam_forward, rawptr(&cam_forward), .VEC3, )
    rl.SetShaderValue( sdf_shader, sdf_loc_tan_fov, rawptr(&tan_fov), .VEC2, )
    rl.SetShaderValue( sdf_shader, sdf_loc_resolution, rawptr(&resolution), .VEC2, )
    rl.SetShaderValueMatrix( sdf_shader, sdf_loc_view, view_matrix, )
    rl.SetShaderValueMatrix( sdf_shader, sdf_loc_projection, projection_matrix, )
    // ECS scene upload is not connected yet.
    // Keep zero until we pass the actual Scene into the renderer.
    count_for_uniform := sphere_count
    rl.SetShaderValue( sdf_shader, sdf_loc_sphere_count, rawptr(&count_for_uniform), .UINT, )

    // Run the fragment shader over the screen.
    rl.BeginShaderMode(sdf_shader)
    rl.DrawRectangle( 0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.WHITE, )
    rl.EndShaderMode()
}

Upload_SDF_Scene :: proc(world: ^ecs.ECS, scene: ^ecs.Scene) -> u32 {
    clear(&gpu_positions)

    for entity in scene.sdf {
        id := int(entity)

        // Ignore invalid or dead entity IDs.
        if id < 0 || id >= len(world.entity_state) {
            continue
        }

        if world.entity_state[id] != .Alive {
            continue
        }

        // Direct ECS position access by entity ID.
        position := world.positions[id]

        // GLSL vec4: xyz = position, w = unused.
        append(
            &gpu_positions,
            position.x,
            position.y,
            position.z,
            0.0,
        )
    }

    count := u32(len(gpu_positions) / 4)
    if count == 0 {
        return 0
    }

    // Each vec4 is 16 bytes.
    required_bytes := count * 16

    // Allocate or grow the SSBO when necessary.
    if scene_ssbo == 0 || required_bytes > scene_ssbo_capacity {
        if scene_ssbo != 0 {
            rlgl.UnloadShaderBuffer(scene_ssbo)
            scene_ssbo = 0
        }

        scene_ssbo = rlgl.LoadShaderBuffer(
            required_bytes,
            rawptr(&gpu_positions[0]),
            rlgl.STREAM_DRAW,
        )

        scene_ssbo_capacity = required_bytes
    } else {
        // Replace the contents of the existing GPU buffer.
        rlgl.UpdateShaderBuffer(
            scene_ssbo,
            rawptr(&gpu_positions[0]),
            required_bytes,
            0,
        )
    }

    // Shader declares layout(std430, binding = 0).
    rlgl.BindShaderBuffer(scene_ssbo, 0)

    return count
}

RLrender :: proc(world: ^ecs.ECS, scene: ^ecs.Scene,) {

    rl.BeginDrawing()
    
    rl.ClearBackground(rl.RAYWHITE)



    rl.UpdateCamera(&camera, .FREE)
    rl.BeginMode3D(camera)
    // Update the dynamic SDF entity positions and upload them.
    sphere_count := Upload_SDF_Scene(world, scene)
    
    //rl.DrawCube({ 0.0, 0.5, 0.0 }, 1.0, 1.0, 1.0, rl.RED)
    //rl.DrawCubeWires({ 0.0, 0.5, 0.0 }, 1.0, 1.0, 1.0, rl.BLACK)   
    rl.DrawGrid(20, 1.0)
    rl.EndMode3D()
    // Render SDFs using the uploaded scene.
    Draw_SDF(sphere_count)
    rl.DrawFPS(10, 10)
    rl.EndDrawing()
}