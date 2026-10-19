#version 430 compatibility

#include "/properties/shadow_settings.glsl"
#include "/src/ssbos/ssbo0_drs.glsl"
#include "/src/utils/shadowmap.glsl"

void main()
{
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    gl_Position.xy /= getDistortionFactorInv(gl_Position.xy);
    gl_Position.xy = gl_Position.xy * drs_scale + drs_offset;
    gl_Position.z *= shadowZScale;
    gl_Position.z = gl_Position.z * 0.5 + 0.5;
}

