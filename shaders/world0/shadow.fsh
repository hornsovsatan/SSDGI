#version 430 core

uniform sampler2D gtexture;

uniform float alphaTestRef;

in vec2 atlasCoordinates;
in vec3 vertexColor;
flat in int blockID;

/* DRAWBUFFERS:0 */
out vec4 color;

void main()
{   
    color = texture(gtexture, atlasCoordinates, -0.5);
    if (color.a < alphaTestRef) discard;
    
    color.rgb *= vertexColor;
    color.a = 0;
    if (blockID==100) {
        color.a = 1.0/255;
        color.rgb = mix(vec3(1), pow(color.rgb, vec3(2.2)),  0.5 * color.a);
    }
}
