
#version 430 core

out vec4 finalColor;

// -----------------------------------------------------------------------------
// ECS SDF scene
// CPU uploads four f32 values per entity:
// xyz = position, w = unused.
// -----------------------------------------------------------------------------

layout(std430, binding = 0) readonly buffer Scene_Buffer
{
    vec4 positions[];
};

uniform uint sphere_count;

// -----------------------------------------------------------------------------
// Camera
// cam_dir length = 1 / tan(vertical FOV / 2)
// -----------------------------------------------------------------------------

uniform vec3 cam_pos;
uniform vec3 cam_dir;
uniform vec3 cam_up;

uniform vec2 screen_center;

// -----------------------------------------------------------------------------
// SDF settings
// -----------------------------------------------------------------------------

const float SDF_RADIUS     = 0.05;
const float HIT_THRESHOLD  = 0.001;
const float NORMAL_EPSILON = 0.001;
const float MAX_DISTANCE   = 100.0;
const int MAX_STEPS        = 64;

// Raylib's default perspective clipping planes.
const float NEAR_PLANE = 0.01;
const float FAR_PLANE  = 1000.0;

// -----------------------------------------------------------------------------
// Sphere SDF
// -----------------------------------------------------------------------------

float sdSphere(vec3 p, vec3 center)
{
    return length(p - center) - SDF_RADIUS;
}

// -----------------------------------------------------------------------------
// Scene SDF
// -----------------------------------------------------------------------------

float sceneSDF(vec3 p, out vec3 nearestCenter)
{
    float bestD2 = 1e30;
    nearestCenter = vec3(0.0);

    for (uint i = 0u; i < sphere_count; ++i)
    {
        vec3 delta = p - positions[i].xyz;
        float d2 = dot(delta, delta);

        if (d2 < bestD2)
        {
            bestD2 = d2;
            nearestCenter = positions[i].xyz;
        }
    }

    return sqrt(bestD2) - SDF_RADIUS;
}


// -----------------------------------------------------------------------------
// Ray direction
// -----------------------------------------------------------------------------

vec3 getRayDirection()
{
    // Screen coordinates centered around the screen center.
    // Dividing both axes by screen height accounts for aspect ratio.

    vec2 nCoord =
        (gl_FragCoord.xy - screen_center) / screen_center.y;

    vec3 forward = normalize(cam_dir);

    // Construct an orthogonal camera basis.
    vec3 right = normalize(cross(forward, cam_up));
    vec3 up    = normalize(cross(right, forward));

    // cam_dir magnitude carries the vertical FOV.
    return normalize(
        cam_dir
        + right * nCoord.x
        + up    * nCoord.y
    );
}

// -----------------------------------------------------------------------------
// Project raymarch distance into conventional OpenGL depth.
// -----------------------------------------------------------------------------

float calcDepth(vec3 rd, float distanceAlongRay)
{
    float localZ = dot(normalize(cam_dir), rd) * distanceAlongRay;

    return (
        (1.0 / localZ) - (1.0 / NEAR_PLANE)
    ) / (
        (1.0 / FAR_PLANE) - (1.0 / NEAR_PLANE)
    );
}

// -----------------------------------------------------------------------------
// Lighting
// -----------------------------------------------------------------------------

vec3 shadeSurface(vec3 position, vec3 normal)
{
    vec3 lightDir = normalize(vec3(-0.3, 0.8, 0.2));

    float diffuse = max(dot(normal, lightDir), 0.0);

    vec3 baseColor = vec3(0.8, 0.7, 0.6);

    float lighting = 0.2 + 0.8 * diffuse;

    return baseColor * lighting;
}

// -----------------------------------------------------------------------------
// Main
// -----------------------------------------------------------------------------

void main()
{
    if (sphere_count == 0u)
    {
        discard;
    }

    vec3 rayOrigin = cam_pos;
    vec3 rayDirection = getRayDirection();

    float rayDistance = 0.0;

    for (int step = 0; step < MAX_STEPS; ++step)
    {
        vec3 position = rayOrigin + rayDirection * rayDistance;

        vec3 nearestCenter;
        float distanceToScene = sceneSDF(position, nearestCenter);

        if (distanceToScene < HIT_THRESHOLD)
        {
            float viewDistance =
                dot(normalize(cam_dir), rayDirection) * rayDistance;

            // Outside the camera clipping range.
            if (viewDistance <= NEAR_PLANE)
            {
                discard;
            }

            float depth = calcDepth(rayDirection, rayDistance);

            if (depth < 0.0 || depth > 1.0)
            {
                discard;
            }

            vec3 normal = normalize(position - nearestCenter);
            vec3 color = shadeSurface(position, normal);

            finalColor = vec4(color, 1.0);

            // Write SDF surface depth into the shared framebuffer.
            gl_FragDepth = depth;

            return;
        }

        rayDistance += max(
            distanceToScene,
            HIT_THRESHOLD * 0.5
        );

        if (rayDistance >= MAX_DISTANCE)
        {
            break;
        }
    }

    // Miss: leave the framebuffer unchanged.
    discard;
}
