
struct VertexOutput
{
    float4 position : SV_Position;
    float2 uv       : TEXCOORD0;
};

VertexOutput main(uint vertexID : SV_VertexID)
{
    // Three vertices forming an oversized triangle.
    float2 positions[3] =
    {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };

    VertexOutput output;

    float2 position = positions[vertexID];

    output.position = float4(position, 0.0, 1.0);
    output.uv = position * 0.5 + 0.5;

    return output;
}
