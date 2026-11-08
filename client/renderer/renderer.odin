
package renderer

import "core:fmt"
import sdl3 "vendor:sdl3"

// ================================================
// Renderer State
// ================================================

Renderer :: struct {
    window:   ^sdl3.Window,
    gpu:      ^sdl3.GPUDevice,

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
    // GPU rendering will be implemented here.
    // For now, the window remains black.
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
