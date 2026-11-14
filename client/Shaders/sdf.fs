#version 330

// ================================================
// CONFIGURATION
// ================================================

#define MAX_STEPS 128
#define MAX_DISTANCE 50000.0
#define SURFACE_EPSILON 0.1

// ================================================
// UNIFORMS
// ================================================

uniform float planetRadius;

uniform vec3 cameraPosition;
uniform vec3 cameraTarget;
uniform vec3 cameraUp;

uniform vec2 resolution;

// ================================================
// FRAGMENT OUTPUT
// ================================================

out vec4 finalColor;

// ================================================
// SDF PRIMITIVES
// ================================================

float sdSphere(vec3 p, float radius)
{
    return length(p) - radius;
}

// ================================================
// SCENE EVALUATION
// ================================================

float sceneSDF(vec3 p)
{
    return sdSphere(p, planetRadius);
}

// ================================================
// SURFACE NORMAL
// ================================================

vec3 calculateNormal(vec3 p)
{
    const float epsilon = 1.0;

    vec2 e = vec2(epsilon, 0.0);

    vec3 normal = vec3(
        sceneSDF(p + e.xyy) - sceneSDF(p - e.xyy),
        sceneSDF(p + e.yxy) - sceneSDF(p - e.yxy),
        sceneSDF(p + e.yyx) - sceneSDF(p - e.yyx)
    );

    return normalize(normal);
}

// ================================================
// DIRECTIONAL LIGHTING
// ================================================

vec3 calculateLighting(vec3 normal)
{
    vec3 lightDirection = normalize(
        vec3(-0.5, 0.8, 0.6)
    );

    float diffuse = max(
        dot(normal, lightDirection),
        0.0
    );

    float ambient = 0.12;

    return vec3(ambient + diffuse);
}

// ================================================
// RAYMARCHING
// ================================================

float raymarch(vec3 rayOrigin, vec3 rayDirection)
{
    float distanceTravelled = 0.0;

    for (int i = 0; i < MAX_STEPS; i++)
    {
        vec3 currentPosition =
            rayOrigin + rayDirection * distanceTravelled;

        float distanceToSurface = sceneSDF(currentPosition);

        if (distanceToSurface < SURFACE_EPSILON)
        {
            return distanceTravelled;
        }

        distanceTravelled += distanceToSurface;

        if (distanceTravelled > MAX_DISTANCE)
        {
            break;
        }
    }

    return -1.0;
}

// ================================================
// CAMERA RAY GENERATION
// ================================================

vec3 generateRayDirection(vec2 uv)
{
    vec3 forward = normalize(cameraTarget - cameraPosition);

    vec3 right = normalize(cross(forward, cameraUp));

    vec3 up = normalize(cross(right, forward));

    vec2 screen = uv * 2.0 - 1.0;

    screen.x *= resolution.x / resolution.y;

    float fov = radians(60.0);

    float scale = tan(fov * 0.5);

    vec3 direction = normalize(
        forward +
        right * screen.x * scale +
        up * screen.y * scale
    );

    return direction;
}

// ================================================
// MAIN
// ================================================

void main()
{
    vec2 uv = gl_FragCoord.xy / resolution;

    vec3 rayOrigin = cameraPosition;

    vec3 rayDirection = generateRayDirection(uv);

    float hitDistance = raymarch(rayOrigin, rayDirection);

    if (hitDistance >= 0.0)
    {
        // Calculate surface position
        vec3 surfacePosition =
            rayOrigin + rayDirection * hitDistance;

        // Calculate surface normal
        vec3 normal = calculateNormal(surfacePosition);

        // Calculate lighting
        vec3 lighting = calculateLighting(normal);

        // Planet base color
        vec3 planetColor = vec3(0.0, 0.0, 1.0);

        finalColor = vec4(
            planetColor * lighting,
            1.0
        );
    }
    else
    {
        finalColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}


