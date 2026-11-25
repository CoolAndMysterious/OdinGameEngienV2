
#version 430 core

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

out vec4 finalColor;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);

    finalColor = texelColor * colDiffuse * fragColor;

    // Preserve the actual rasterized window-space depth.
    gl_FragDepth = gl_FragCoord.z;
}
