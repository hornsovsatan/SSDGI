
//MATRICES
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

//CAMERA
uniform vec3 previousCameraPosition;
uniform vec3 cameraPosition;
uniform vec3 cameraVector;

//SCREEN
uniform vec2 resolution;
uniform vec2 resolutionInv;
uniform float near;
uniform float far;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform float frameTime;


uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform float sunAngle;
uniform float shadowAngle;
uniform vec3 fogColor;
uniform bool hideGUI;
uniform float constantMood;
uniform int isEyeInWater;
uniform float eyeBrightnessSky;
uniform int biome_precipitation;
uniform float rainStrength;
uniform int moonPhase;


//SAMPLERS
uniform  sampler2D depthtex0;
uniform  sampler2D depthtex1;
uniform  sampler2D depthtex2;

uniform  sampler2D colortex0;
uniform usampler2D colortex1;
uniform  sampler2D colortex2;
uniform usampler2D colortex3;

uniform  sampler2D colortex4;
uniform  sampler2D colortex5;
uniform usampler2D colortex6;
uniform  sampler2D colortex7;
uniform  sampler2D colortex8;
uniform  sampler2D colortex9;
// uniform  sampler2D colortex10;
// uniform  sampler2D colortex11;
// uniform  sampler2D colortex12;
// uniform  sampler2D colortex13;
// uniform  sampler2D colortex14;
// uniform  sampler2D colortex15;
uniform  sampler2D noisetex;
uniform  sampler2D shadowtex0;
uniform  sampler2D shadowtex1;
uniform  sampler2DShadow shadowtex0HW;
uniform  sampler2DShadow shadowtex1HW;
uniform  sampler2D shadowcolor0;