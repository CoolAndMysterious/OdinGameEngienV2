
#version 430 core

in vec2 fragTexCoord;
out vec4 finalColor;

// -----------------------------------------------------------------------------
// SDF scene buffer
// CPU layout: four f32 values per entity.
// xyz = position, w = unused.
// -----------------------------------------------------------------------------

layout(std430, binding = 0) readonly buffer Scene_Buffer
{
    vec4 positions[];
};

uniform uint sphere_count;

// -----------------------------------------------------------------------------
// Camera
// -----------------------------------------------------------------------------

uniform vec3 cam_pos;
uniform vec3 cam_right;
uniform vec3 cam_up;
uniform vec3 cam_forward;

uniform vec2 tan_fov;
uniform vec2 resolution;

uniform mat4 view_matrix;
uniform mat4 proj_matrix;

// -----------------------------------------------------------------------------
// SDF settings
// -----------------------------------------------------------------------------

const float SDF_RADIUS     = 0.05;
const float HIT_THRESHOLD  = 0.001;
const float NORMAL_EPSILON = 0.001;
const float MAX_DISTANCE   = 100.0;
const int MAX_STEPS        = 128;

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

float sceneSDF(vec3 p)
{
    float d = 1e20;

    for (uint i = 0u; i < sphere_count; ++i)
    {
        d = min(d, sdSphere(p, positions[i].xyz));
    }

    return d;
}

// -----------------------------------------------------------------------------
// Surface normal
// -----------------------------------------------------------------------------

vec3 calcNormal(vec3 p)
{
    float e = NORMAL_EPSILON;

    vec3 gradient = vec3(
        sceneSDF(p + vec3(e, 0.0, 0.0)) -
        sceneSDF(p - vec3(e, 0.0, 0.0)),

        sceneSDF(p + vec3(0.0, e, 0.0)) -
        sceneSDF(p - vec3(0.0, e, 0.0)),

        sceneSDF(p + vec3(0.0, 0.0, e)) -
        sceneSDF(p - vec3(0.0, 0.0, e))
    );

    return normalize(gradient);
}

// -----------------------------------------------------------------------------
// Camera ray
// -----------------------------------------------------------------------------

vec3 getRayDirection()
{
    // Convert pixel coordinates to centered NDC coordinates.
    // NDC ranges from -1 to +1 on both axes.
    vec2 uv = gl_FragCoord.xy / resolution;
    vec2 ndc = uv * 2.0 - 1.0;

    // tan_fov.x = tan(vertical FOV / 2) * aspect ratio
    // tan_fov.y = tan(vertical FOV / 2)
    //
    // This matches the FOV calculation in renderer.odin.

    return normalize(
        cam_forward
        + cam_right * ndc.x * tan_fov.x
        + cam_up    * ndc.y * tan_fov.y
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
    // No SDF entities: preserve the raster pixel.
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

        float distanceToScene = sceneSDF(position);

        // Surface hit.
        if (distanceToScene < HIT_THRESHOLD)
        {
            // Transform the world-space hit into clip space.
            vec4 clipPosition =
                proj_matrix *
                view_matrix *
                vec4(position, 1.0);

            if (clipPosition.w <= 0.0)
            {
                discard;
            }

            float ndcDepth = clipPosition.z / clipPosition.w;

            // OpenGL NDC depth [-1, 1] to window depth [0, 1].
            float hitDepth = ndcDepth * 0.5 + 0.5;

            if (hitDepth < 0.0 || hitDepth > 1.0)
            {
                discard;
            }

            vec3 normal = calcNormal(position);
            vec3 color = shadeSurface(position, normal);

            finalColor = vec4(color, 1.0);

            // Write the raymarched surface depth.
            gl_FragDepth = hitDepth;

            return;
        }

        // Sphere tracing step.
        rayDistance += max(
            distanceToScene,
            HIT_THRESHOLD * 0.5
        );

        if (rayDistance >= MAX_DISTANCE)
        {
            break;
        }
    }

    // Miss: preserve the raster color and depth.
    discard;
}
