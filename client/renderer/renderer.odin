package renderer

import "core:fmt"
import sdl "vendor:sdl3"

// ================================================
// Renderer State
// ================================================

Renderer :: struct {
    window: ^sdl.Window,
    gpu:    ^sdl.GPUDevice,
    // Current frame information
    swapchain_width:  u32,
    swapchain_height: u32,

    running: bool,
}

// ================================================
// Initialize
// ================================================

Init :: proc(r: ^Renderer) -> bool {
    // Initialize sdl
    if !sdl.Init({.VIDEO}) {
        fmt.println("SDL initialization failed:", sdl.GetError())
        return false
    }
    // Create window
    r.window = sdl.CreateWindow( "Odin Engine", 1280, 720, {.RESIZABLE}, )

    if r.window == nil {
        fmt.println("Window creation failed:", sdl.GetError())
        sdl.Quit()
        return false
    }

    // Create Vulkan GPU device
    r.gpu = sdl.CreateGPUDevice( {.SPIRV}, true, "vulkan", )

    if r.gpu == nil {
        fmt.println("GPU creation failed:", sdl.GetError())
        sdl.DestroyWindow(r.window)
        sdl.Quit()
        return false
    }

    // Connect GPU to window
    if !sdl.ClaimWindowForGPUDevice(r.gpu, r.window) {
        fmt.println("GPU window claim failed:", sdl.GetError())
        sdl.DestroyGPUDevice(r.gpu)
        sdl.DestroyWindow(r.window)
        sdl.Quit()
        return false
    }

    r.running = true

    fmt.println("Renderer initialized successfully!")

    return true
}

// ================================================
// Update
// ================================================

Process_Events :: proc(r: ^Renderer) {

    event: sdl.Event

    for sdl.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:
            r.running = false

        case .WINDOW_CLOSE_REQUESTED:
            r.running = false
        }
    }
}

// ================================================
// Running State
// ================================================

Is_Running :: proc(r: ^Renderer) -> bool {
    return r.running
}

// ================================================
// Draw
// ================================================

Draw :: proc(r: ^Renderer) {

    // 1. Acquire GPU command buffer
    cmd := sdl.AcquireGPUCommandBuffer(r.gpu)

    if cmd == nil {
        fmt.println("Command buffer acquisition failed:", sdl.GetError())
        return
    }

    // 2. Acquire swapchain texture
    swapchain_texture: ^sdl.GPUTexture
    width, height: u32

    if !sdl.WaitAndAcquireGPUSwapchainTexture( cmd, r.window, &swapchain_texture, &r.swapchain_width, &r.swapchain_height, ) {
        
        fmt.println("Swapchain acquisition failed:", sdl.GetError())

        // Submit the command buffer instead of cancelling it.
        if !sdl.SubmitGPUCommandBuffer(cmd) {
            fmt.println("GPU submission failed:", sdl.GetError())
        }
        return
    }

    // 3. Handle minimized window
    if swapchain_texture == nil {
        if !sdl.SubmitGPUCommandBuffer(cmd) {
            fmt.println("GPU submission failed:", sdl.GetError())
        }
        return
    }

    // 4. Describe our color attachment
    color_target := sdl.GPUColorTargetInfo{
        texture     = swapchain_texture,
        load_op     = .CLEAR,
        clear_color = sdl.FColor([4]f32{0.08, 0.12, 0.20, 1.0}),
        store_op    = .STORE,
    }

    // 5. Begin render pass
    pass := sdl.BeginGPURenderPass(
        cmd,
        &color_target,
        1,
        nil,
    )

    // No drawing commands yet.
    // The render pass will simply clear the window.

    // 6. End render pass
    sdl.EndGPURenderPass(pass)

    // 7. Submit command buffer
    if !sdl.SubmitGPUCommandBuffer(cmd) {
        fmt.println("GPU submission failed:", sdl.GetError())
        return
    }
}

// ================================================
// Shutdown
// ================================================

Shutdown :: proc(r: ^Renderer) {

    if r.gpu != nil {
        sdl.ReleaseWindowFromGPUDevice(r.gpu, r.window)
        sdl.DestroyGPUDevice(r.gpu)
    }

    if r.window != nil {
        sdl.DestroyWindow(r.window)
    }

    sdl.Quit()

    fmt.println("Renderer shutdown.")
}