
#version 330

out vec4 finalColor;

// Screen dimensions
uniform vec2 uResolution;

// Rendering settings
#define MAX_STEPS 128
#define MAX_DISTANCE 100000.0
#define SURFACE_EPSILON 0.01

// ==================================================
// 1. SCENE EVALUATION
// ==================================================

float mapScene(vec3 position)
{
    // This is where our SDF scene will be evaluated.
    // We'll implement our first primitive in the next step.

    return 1e20;
}

// ==================================================
// 2. RAYMARCHING
// ==================================================

float raymarch(vec3 origin, vec3 direction)
{
    float distanceTravelled = 0.0;

    for (int i = 0; i < MAX_STEPS; i++)
    {
        vec3 position = origin
            + direction * distanceTravelled;

        float distance = mapScene(position);

        // Surface found
        if (distance < SURFACE_EPSILON)
        {
            return distanceTravelled;
        }

        // Advance along the ray
        distanceTravelled += distance;

        // Too far away
        if (distanceTravelled > MAX_DISTANCE)
        {
            break;
        }
    }

    // No surface found
    return -1.0;
}

// ==================================================
// 3. MAIN RENDERING
// ==================================================

void main()
{
    // Convert pixel coordinates into normalized coordinates
    vec2 uv = gl_FragCoord.xy / uResolution;

    uv = uv * 2.0 - 1.0;

    // Temporary fixed camera
    vec3 cameraPosition = vec3(0.0, 0.0, 5.0);

    vec3 rayDirection = normalize(vec3(
        uv.x * (uResolution.x / uResolution.y),
        uv.y,
        -1.5
    ));

    // Trace the ray
    float hit = raymarch(
        cameraPosition,
        rayDirection
    );

    // Background
    vec3 color = vec3(0.02, 0.025, 0.04);

    // Output pixel
    finalColor = vec4(color, 1.0);
}
