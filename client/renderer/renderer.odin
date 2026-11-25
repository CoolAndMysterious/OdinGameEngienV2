package renderer

import "core:fmt"
import "core:math"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

import ecs "../ECS"

// -----------------------------------------------------------------------------
// Camera
// -----------------------------------------------------------------------------

camera := rl.Camera3D{
    position   = {0, 2, 6},
    target     = {0, 1, 0},
    up         = {0, 1, 0},
    fovy       = 60,
    projection = .PERSPECTIVE,
}

// -----------------------------------------------------------------------------
// GPU resources
// -----------------------------------------------------------------------------

scene_ssbo: u32 = 0
scene_ssbo_capacity: u32 = 0

gpu_positions: [dynamic]f32

hybrid_target: rl.RenderTexture2D

sdf_shader: rl.Shader
raster_shader: rl.Shader

// -----------------------------------------------------------------------------
// SDF shader uniform locations
// -----------------------------------------------------------------------------

sdf_loc_sphere_count: i32
sdf_loc_cam_pos:      i32
sdf_loc_cam_dir:      i32
sdf_loc_cam_up:       i32
sdf_loc_screen_center: i32

// -----------------------------------------------------------------------------
// Create a framebuffer with a writable depth texture.
// Based on Raylib's LoadRenderTextureDepthTex example.
// -----------------------------------------------------------------------------

Create_Hybrid_Target :: proc(
    width: i32,
    height: i32,
) -> rl.RenderTexture2D {

    target: rl.RenderTexture2D

    target.id = rlgl.LoadFramebuffer()

    if target.id == 0 {
        fmt.println("ERROR: Failed to create hybrid framebuffer")
        return {}
    }

    rlgl.EnableFramebuffer(target.id)

    // Color attachment.
    target.texture.id = rlgl.LoadTexture(
        nil,
        width,
        height,
        i32(rl.PixelFormat.UNCOMPRESSED_R8G8B8A8),
        1,
    )

    target.texture.width = width
    target.texture.height = height
    target.texture.format = .UNCOMPRESSED_R8G8B8A8
    target.texture.mipmaps = 1

    // Real depth texture, not a renderbuffer.
    target.depth.id = rlgl.LoadTextureDepth(
        width,
        height,
        false,
    )

    target.depth.width = width
    target.depth.height = height
    target.depth.mipmaps = 1

    // Check texture allocation.
    if target.texture.id == 0 || target.depth.id == 0 {
        rlgl.DisableFramebuffer()

        if target.texture.id != 0 {
            rlgl.UnloadTexture(target.texture.id)
        }

        if target.depth.id != 0 {
            rlgl.UnloadTexture(target.depth.id)
        }

        rlgl.UnloadFramebuffer(target.id)

        fmt.println("ERROR: Failed to allocate hybrid framebuffer textures")
        return {}
    }

    // Attach color texture.
    rlgl.FramebufferAttach(
        target.id,
        target.texture.id,
        i32(rlgl.FramebufferAttachType.COLOR_CHANNEL0),
        i32(rlgl.FramebufferAttachTextureType.TEXTURE2D),
        0,
    )

    // Attach depth texture.
    rlgl.FramebufferAttach(
        target.id,
        target.depth.id,
        i32(rlgl.FramebufferAttachType.DEPTH),
        i32(rlgl.FramebufferAttachTextureType.TEXTURE2D),
        0,
    )

    complete := rlgl.FramebufferComplete(target.id)

    rlgl.DisableFramebuffer()

    if !complete {
        fmt.println("ERROR: Hybrid framebuffer is incomplete")

        rlgl.UnloadTexture(target.texture.id)
        rlgl.UnloadTexture(target.depth.id)
        rlgl.UnloadFramebuffer(target.id)

        return {}
    }

    fmt.println("Hybrid framebuffer created successfully")

    return target
}

// -----------------------------------------------------------------------------
// Destroy custom framebuffer
// -----------------------------------------------------------------------------

Unload_Hybrid_Target :: proc(target: rl.RenderTexture2D) {
    if target.id == 0 {
        return
    }

    rlgl.UnloadTexture(target.texture.id)
    rlgl.UnloadTexture(target.depth.id)
    rlgl.UnloadFramebuffer(target.id)
}

// -----------------------------------------------------------------------------
// Initialization
// -----------------------------------------------------------------------------

RL_Init :: proc() {

    // SDF raymarch shader.
    sdf_shader = rl.LoadShader(
        nil,
        cstring("Shared/Shaders/SDF_RayMarcher.fs"),
    )

    if sdf_shader.id == 0 {
        fmt.println("ERROR: SDF shader failed to load")
        return
    }

    // Raster depth-writing shader.
    raster_shader = rl.LoadShader(
        nil,
        cstring("Shared/Shaders/SDF_Raster.fs"),
    )

    if raster_shader.id == 0 {
        fmt.println("ERROR: Raster shader failed to load")
        return
    }

    // Cache SDF uniform locations.
    sdf_loc_sphere_count = rl.GetShaderLocation(
        sdf_shader,
        cstring("sphere_count"),
    )

    sdf_loc_cam_pos = rl.GetShaderLocation(
        sdf_shader,
        cstring("cam_pos"),
    )

    sdf_loc_cam_dir = rl.GetShaderLocation(
        sdf_shader,
        cstring("cam_dir"),
    )

    sdf_loc_cam_up = rl.GetShaderLocation(
        sdf_shader,
        cstring("cam_up"),
    )

    sdf_loc_screen_center = rl.GetShaderLocation(
        sdf_shader,
        cstring("screen_center"),
    )

    // Create the custom framebuffer at the current screen resolution.
    hybrid_target = Create_Hybrid_Target(
        rl.GetScreenWidth(),
        rl.GetScreenHeight(),
    )

    if hybrid_target.id == 0 {
        fmt.println("ERROR: Hybrid rendering initialization failed")
        return
    }

    fmt.println("Hybrid SDF + raster renderer initialized")
}

// -----------------------------------------------------------------------------
// ECS -> GPU scene upload
// -----------------------------------------------------------------------------

Upload_SDF_Scene :: proc(
    world: ^ecs.ECS,
    scene: ^ecs.Scene,
) -> u32 {

    clear(&gpu_positions)

    for entity in scene.sdf {

        id := int(entity)

        // Ignore invalid and dead entities.
        if id < 0 || id >= len(world.entity_state) {
            continue
        }

        if world.entity_state[id] != .Alive {
            continue
        }

        // Read position directly from ECS using entity ID.
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

    required_bytes := count * 16

    // Allocate or grow the GPU buffer.
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

        if scene_ssbo == 0 {
            fmt.println("ERROR: Failed to allocate SDF SSBO")
            scene_ssbo_capacity = 0
            return 0
        }

        scene_ssbo_capacity = required_bytes

    } else {

        // Upload current frame's positions.
        rlgl.UpdateShaderBuffer(
            scene_ssbo,
            rawptr(&gpu_positions[0]),
            required_bytes,
            0,
        )
    }

    // Match GLSL binding = 0.
    rlgl.BindShaderBuffer(scene_ssbo, 0)

    return count
}

// -----------------------------------------------------------------------------
// Set camera uniforms and execute SDF fullscreen pass.
// Must be called while hybrid_target is active.
// -----------------------------------------------------------------------------

Draw_SDF :: proc(sphere_count: u32) {

    if sphere_count == 0 || scene_ssbo == 0 {
        return
    }

    // Current camera position.
    cam_pos := camera.position

    // Calculate normalized direction toward camera target.
    dx := f64(camera.target.x) - f64(camera.position.x)
    dy := f64(camera.target.y) - f64(camera.position.y)
    dz := f64(camera.target.z) - f64(camera.position.z)

    direction_length := math.sqrt(
        dx * dx + dy * dy + dz * dz,
    )

    if direction_length <= 0.000001 {
        return
    }

    forward := rl.Vector3{
        f32(dx / direction_length),
        f32(dy / direction_length),
        f32(dz / direction_length),
    }

    // Raylib's hybrid example encodes vertical FOV in cam_dir length.
    cam_dist := f32(
        1.0 / math.tan(
            f64(camera.fovy) * math.PI / 360.0,
        ),
    )

    cam_dir := rl.Vector3{
        forward[0] * cam_dist,
        forward[1] * cam_dist,
        forward[2] * cam_dist,
    }

    cam_up := camera.up

    screen_center := rl.Vector2{
        f32(hybrid_target.texture.width) * 0.5,
        f32(hybrid_target.texture.height) * 0.5,
    }

    count_value := sphere_count

    // Send camera and scene uniforms.
    rl.SetShaderValue(
        sdf_shader,
        sdf_loc_cam_pos,
        rawptr(&cam_pos),
        .VEC3,
    )

    rl.SetShaderValue(
        sdf_shader,
        sdf_loc_cam_dir,
        rawptr(&cam_dir),
        .VEC3,
    )

    rl.SetShaderValue(
        sdf_shader,
        sdf_loc_cam_up,
        rawptr(&cam_up),
        .VEC3,
    )

    rl.SetShaderValue(
        sdf_shader,
        sdf_loc_screen_center,
        rawptr(&screen_center),
        .VEC2,
    )

    rl.SetShaderValue(
        sdf_shader,
        sdf_loc_sphere_count,
        rawptr(&count_value),
        .UINT,
    )

    // Run fullscreen raymarch pass.
    rlgl.BindShaderBuffer(scene_ssbo, 0)

    rl.BeginShaderMode(sdf_shader)

    rl.DrawRectangle(
        0,
        0,
        hybrid_target.texture.width,
        hybrid_target.texture.height,
        rl.WHITE,
    )

    rl.EndShaderMode()
}

// -----------------------------------------------------------------------------
// Main rendering
// -----------------------------------------------------------------------------

RLrender :: proc(
    world: ^ecs.ECS,
    scene: ^ecs.Scene,
) {

    if hybrid_target.id == 0 {
        return
    }

    // Update the single existing Raylib camera.
    rl.UpdateCamera(&camera, .FREE)

    // Rebuild and upload dynamic ECS SDF positions.
    sphere_count := Upload_SDF_Scene(world, scene)

    // -------------------------------------------------------------------------
    // Render both pipelines into the same framebuffer.
    // -------------------------------------------------------------------------

    rl.BeginTextureMode(hybrid_target)

    // Clear both color and depth attachments.
    rl.ClearBackground(rl.WHITE)

    // Required for the SDF gl_FragDepth pass.
    rlgl.EnableDepthTest()

    // 1. SDF raymarch pass.
    Draw_SDF(sphere_count)

    // 2. Normal rasterization pass.
    rl.BeginMode3D(camera)

    rl.BeginShaderMode(raster_shader)

    // Your ordinary raster geometry goes here.
    rl.DrawGrid(20, 1.0)

    // Future examples:
    // rl.DrawCube(...)
    // rl.DrawModel(...)
    // rl.DrawSphere(...)

    rl.EndShaderMode()

    rl.EndMode3D()

    rl.EndTextureMode()

    // -------------------------------------------------------------------------
    // Present completed hybrid framebuffer to window.
    // -------------------------------------------------------------------------

    rl.BeginDrawing()

    rl.ClearBackground(rl.RAYWHITE)

    // Render textures are vertically flipped in Raylib/OpenGL.
    source := rl.Rectangle{
        x = 0,
        y = 0,
        width = f32(hybrid_target.texture.width),
        height = -f32(hybrid_target.texture.height),
    }

    rl.DrawTextureRec(
        hybrid_target.texture,
        source,
        rl.Vector2{0, 0},
        rl.WHITE,
    )

    rl.DrawFPS(10, 10)

    rl.EndDrawing()
}

// -----------------------------------------------------------------------------
// Shutdown
// -----------------------------------------------------------------------------

RL_Shutdown :: proc() {

    if scene_ssbo != 0 {
        rlgl.UnloadShaderBuffer(scene_ssbo)
        scene_ssbo = 0
        scene_ssbo_capacity = 0
    }

    Unload_Hybrid_Target(hybrid_target)
    hybrid_target = {}

    if sdf_shader.id != 0 {
        rl.UnloadShader(sdf_shader)
        sdf_shader = {}
    }

    if raster_shader.id != 0 {
        rl.UnloadShader(raster_shader)
        raster_shader = {}
    }

    delete(gpu_positions)
}
