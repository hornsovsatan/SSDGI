#version 430 compatibility

#include "/properties/shadow_settings.glsl"
#include "/src/ssbos/ssbo0_drs.glsl"
#include "/src/utils/shadowmap.glsl"

out vec2 atlasCoordinates;
out vec3 vertexColor;
flat out int blockID;

in vec2 mc_Entity;

uniform int frameCounter;
uniform int renderStage;

void main()
{
    atlasCoordinates = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color.rgb;
    blockID = int(mc_Entity.x);
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    gl_Position.xy /= getDistortionFactorInv(gl_Position.xy);
    gl_Position.xy = gl_Position.xy * drs_scale + drs_offset;
    gl_Position.z *= shadowZScale;
    gl_Position.z = gl_Position.z * 0.5 + 0.5;
    if (renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT)
        gl_Position.z -= 1.0;
}

