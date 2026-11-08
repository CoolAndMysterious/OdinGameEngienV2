
package renderer

import "core:fmt"
import sdl3 "vendor:sdl3"

// ================================================
// Renderer State
// ================================================

Renderer :: struct {
    window: ^sdl3.Window,
    gpu:    ^sdl3.GPUDevice,

    // Current frame information
    swapchain_width:  u32,
    swapchain_height: u32,

    running: bool,
}

// ================================================
// Initialize
// ================================================

Init :: proc(r: ^Renderer) -> bool {

    // Initialize SDL3
    if !sdl3.Init({.VIDEO}) {
        fmt.println("SDL initialization failed:", sdl3.GetError())
        return false
    }

    // Create window
    r.window = sdl3.CreateWindow( "Odin Engine", 1280, 720, {.RESIZABLE}, )

    if r.window == nil {
        fmt.println("Window creation failed:", sdl3.GetError())
        sdl3.Quit()
        return false
    }

    // Create Vulkan GPU device
    r.gpu = sdl3.CreateGPUDevice( {.SPIRV}, true, "vulkan", )

    if r.gpu == nil {
        fmt.println("GPU creation failed:", sdl3.GetError())
        sdl3.DestroyWindow(r.window)
        sdl3.Quit()
        return false
    }

    // Connect GPU to window
    if !sdl3.ClaimWindowForGPUDevice(r.gpu, r.window) {
        fmt.println("GPU window claim failed:", sdl3.GetError())
        sdl3.DestroyGPUDevice(r.gpu)
        sdl3.DestroyWindow(r.window)
        sdl3.Quit()
        return false
    }

    r.running = true

    fmt.println("Renderer initialized successfully!")

    return true
}

// ================================================
// Update
// ================================================

Update :: proc(r: ^Renderer) {

    event: sdl3.Event

    for sdl3.PollEvent(&event) {
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
    cmd := sdl3.AcquireGPUCommandBuffer(r.gpu)

    if cmd == nil {
        fmt.println("Command buffer acquisition failed:", sdl3.GetError())
        return
    }

    // 2. Acquire swapchain texture
    swapchain_texture: ^sdl3.GPUTexture
    width, height: u32

    if !sdl3.WaitAndAcquireGPUSwapchainTexture( cmd, r.window, &swapchain_texture, &width, &height, ) {
        
        fmt.println("Swapchain acquisition failed:", sdl3.GetError())

        // Submit the command buffer instead of cancelling it.
        if !sdl3.SubmitGPUCommandBuffer(cmd) {
            fmt.println("GPU submission failed:", sdl3.GetError())
        }
        return
    }

    // 3. Handle minimized window
    if swapchain_texture == nil {
        if !sdl3.SubmitGPUCommandBuffer(cmd) {
            fmt.println("GPU submission failed:", sdl3.GetError())
        }
        return
    }

    // 4. Describe our color attachment
    color_target := sdl3.GPUColorTargetInfo{
        texture     = swapchain_texture,
        load_op     = .CLEAR,
        clear_color = sdl3.FColor([4]f32{0.08, 0.12, 0.20, 1.0}),
        store_op    = .STORE,
    }

    // 5. Begin render pass
    pass := sdl3.BeginGPURenderPass(
        cmd,
        &color_target,
        1,
        nil,
    )

    // No drawing commands yet.
    // The render pass will simply clear the window.

    // 6. End render pass
    sdl3.EndGPURenderPass(pass)

    // 7. Submit command buffer
    if !sdl3.SubmitGPUCommandBuffer(cmd) {
        fmt.println("GPU submission failed:", sdl3.GetError())
        return
    }
}

// ================================================
// Shutdown
// ================================================

Shutdown :: proc(r: ^Renderer) {

    if r.gpu != nil {
        sdl3.ReleaseWindowFromGPUDevice(r.gpu, r.window)
        sdl3.DestroyGPUDevice(r.gpu)
    }

    if r.window != nil {
        sdl3.DestroyWindow(r.window)
    }

    sdl3.Quit()

    fmt.println("Renderer shutdown.")
}



Acquire_Swapchain :: proc(r: ^Renderer) -> bool {

    // Get a GPU command buffer
    cmd := sdl3.AcquireGPUCommandBuffer(r.gpu)

    if cmd == nil {
        fmt.println("Command buffer acquisition failed:", sdl3.GetError())
        return false
    }

    // Get the next available swapchain texture
    swapchain_texture: ^sdl3.GPUTexture

    if !sdl3.WaitAndAcquireGPUSwapchainTexture(
        cmd,
        r.window,
        &swapchain_texture,
        &r.swapchain_width,
        &r.swapchain_height,
    ) {
        fmt.println("Swapchain acquisition failed:", sdl3.GetError())
        if !sdl3.CancelGPUCommandBuffer(cmd) {
            fmt.println("Command buffer cancellation failed:", sdl3.GetError())
        }
        return false
    }

    // A nil texture can happen when the window is minimized.
    if swapchain_texture == nil {
        if !sdl3.CancelGPUCommandBuffer(cmd) {
            fmt.println("Command buffer cancellation failed:", sdl3.GetError())
        }
        return true
    }

    fmt.println(
        "Swapchain acquired:",
        r.swapchain_width,
        "x",
        r.swapchain_height,
    )

    // We'll add the render pass and submit the command buffer next.
    if !sdl3.CancelGPUCommandBuffer(cmd) {
            fmt.println("Command buffer cancellation failed:", sdl3.GetError())
        }

    return true
}
