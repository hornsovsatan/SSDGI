/*
 * All Rights Reserved
 * 
 * Copyright (c) 2025-2026 lipesto
 *
 * This source code is protected by copyright law and may not be copied,
 * modified, published, distributed, sublicensed, or used in any form without 
 * the express written permission of the copyright holder.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT, OR OTHERWISE, ARISING FROM,
 * OUT OF, OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#define OVERWORLD_EXCLUSIVE

const vec2 workGroupsRender = vec2(1.0, 1.0);
layout (local_size_x = 8, local_size_y = 16) in;

#include "/src/common.glsl"
#include "/src/uniforms.glsl"
#include "/properties/shadow_settings.glsl"
#include "/src/ssbos/ssbo0_drs.glsl"
#include "/src/utils/shadowmap.glsl"
#include "/src/utils/compute_utils.glsl"
#include "/src/surface/material.glsl"


uniform sampler2D skyLUTtex;
uniform sampler2D shadowlodtex;
uniform sampler2D dgbu2tex;



#define SHADOW_SURFACE 
#include "/src/lighting/shadow.glsl"
#include "/src/lighting/atmosphere.glsl"
#include "/src/lighting/clouds.glsl"
#include "/src/lighting/brdf.glsl"

layout (r11f_g11f_b10f) uniform image2D colorimg2;
layout (r11f_g11f_b10f) uniform image2D gpbColor0;


void main() {
    shadowSpaceScale = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z * shadowZScale);
    drsScale       = drs_scale;
    drsOffset      = drs_offset;
    drsScaleWindow = drs_scale * 0.5;
    drsOffsetWindow = drs_offset * 0.5 + 0.5;

    ivec2 fragCoord = ivec2(gl_GlobalInvocationID);
    if (!inBoundsTR(fragCoord, resolution)) return;
    
    float depth = texelFetch(depthtex0, fragCoord, 0).r;
    float depth2 = texelFetch(depthtex2, fragCoord, 0).r;
    material surface = sampleMaterial(colortex0, colortex1, fragCoord);
    float sss = sampleMaterialSSS(colortex3, fragCoord);
    surface.trueNormal = mat3(gbufferModelViewInverse) * surface.trueNormal;
    surface.normal = mat3(gbufferModelViewInverse) * surface.normal;
    vec3 sun = normalize(mat3(gbufferModelViewInverse) * (shadowLightPosition));
    
    
    
    bool sunlit = (dot(surface.normal, sun) > 0.0 || sss > 0.0);
    if (surface.lightmap.y == 0.0 && constantMood > 0.01 && isEyeInWater == 0) sunlit = false; 
    
    vec3 outEmission = vec3(0);
    vec3 outSpecular = vec3(0);
    
    if (sunlit && depth != 1.0) {
        vec3 position = projectPoint(vec3((fragCoord + 0.5) * resolutionInv, depth) * 2.0 - 1.0, gbufferProjectionInverse);
        if (depth != depth2) position /= 0.3;
        position = mat4x3(gbufferModelViewInverse) * vec4(position, 1.0);
        
        
        
        vec3 chunkPos = floor((position + sign(position) * 0.1) / 16.0 + fract(cameraPosition / 16));
        const float shadowRadius = shadowDistanceRenderMul * 8.0;
        bool chunkMask = chunkPos == clamp(chunkPos, -shadowRadius, shadowRadius);
        
        vec3 fallbackShadow = vec3(sss > 0.0 ? smoothstep(-0.2, 0.1, dot(surface.normal, sun)) : 1.0);
        fallbackShadow *= surface.lightmap.y * 0.95 + 0.05;
        
        vec3 shadow = fallbackShadow;
        if (chunkMask) {
            vec2 blockerData = vec2(0);
            const int radius = 1;
            for (int x = -radius; x<=radius; x++) {
            for (int y = -radius; y<=radius; y++) {
                blockerData += textureLod(dgbu2tex, (fragCoord + 0.5 + ivec2(x,y) * 4) * resolutionInv / 3,0).rg;
            }}
            blockerData.x *= -32.0;
            blockerData.y *= 65535.0;
            
            
            if (blockerData.y == maxBlockerWsum && -blockerData.x/maxBlockerWsum < 0.01 && sss != 0.0) shadow = vec3(0.0);
            else
                shadow = amalgamaShadow(position, surface.trueNormal, sss, blockerData, fragCoord);
            
            if (shadowDistanceRenderMul * 8.0 * 16.0 < far){
                vec3 m = saturate((-abs(position / 16.0) + shadowRadius) * 1.0 / shadowDistanceRenderMul);
                shadow = mix(fallbackShadow, shadow, min(m.x, min(m.y, m.z)));
            }
            
        }
        
        if (surface.lightmap.y == 0.0 && constantMood > 0.0001 && isEyeInWater == 0) shadow *= saturate(1.0 - constantMood * 100);
        
        #ifdef CLOUD_SHADOWS
        shadow *= getCloudShadow(position, sun);
        #endif
        
        
        vec2 lutUv = vec2(sun.y * (10 - seaLevel + earthRadius) / atmosphereRadius * 0.5 + 0.5, (70 - seaLevel) /atmosphereWidth);
        vec3 sunAttenuation = textureLod(skyLUTtex, lutUv, 0).rgb;
        radianceSeparate radiance = BRDF(sun, -normalize(position), surface);
        if (sss > 0.0) radiance.diffuse = vec3(1.0 / (4.0 * M_PI));
        vec3 light = sunAttenuation * shadow * (sunAngle > 0.5 ? moonIrradiance : sunIrradiance);
        
        float lambertianBlend = surface.roughness * surface.roughness;
        vec3 lambertian = light * (radiance.diffuse * surface.albedo + radiance.specular * lambertianBlend);
        vec3 specular = light * (radiance.specular * (1.0 - lambertianBlend));
        
        outEmission = lambertian;
        outSpecular = specular;
    }
    if (depth != 1.0) outEmission += texelFetch(colortex2, fragCoord, 0).rgb;
    
    
    imageStore(colorimg2, fragCoord, vec4(outEmission,0));
    imageStore(gpbColor0, fragCoord, vec4(outSpecular,0));
}