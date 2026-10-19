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

#include "/src/common.glsl"
#include "/src/uniforms.glsl"
#include "/src/utils/storage.glsl"
#include "/src/surface/material.glsl"
#include "/src/utils/random.glsl"
#include "/properties/shader_settings.glsl"
#include "/src/ssbos/ssbo6.glsl"

uniform sampler2D skytex;
uniform sampler2D skyLUTtex;
uniform sampler2D moontex;
uniform sampler2D hiZtex;
#include "/src/lighting/atmosphere.glsl"
#include "/properties/rt_settings.glsl"
#include "/src/ray_tracing/ssrt.glsl"
#include "/src/lighting/translucents.glsl"


float getPixelSize(float depth) {
    vec4 p = gbufferProjectionInverse * vec4(resolutionInv, depth * 2.0 - 1.0, 1.0);
    float pixelSize = p.x / p.w * 2.0;
    return pixelSize;
}

layout(r11f_g11f_b10f) uniform image2D gpbColor0;
layout(r11f_g11f_b10f) uniform image2D gpbColor2;
uniform sampler2D gpbColor2t;

/* RENDERTARGETS: 7 */
out vec4 color;

void main() {
    hizLod2Offset       = ceil(resolution.y / HIZ_PIXEL_SIZE);
    hizLod3Offset       = ceil(resolution.y / HIZ_PIXEL_SIZE) + ceil(resolution.y / HIZ_PIXEL_SIZE / 4.0);
    hizLod3EarlyOffset  = int(ceil(resolution.x / HIZ_PIXEL_SIZE / 16.0));
    hizLod3EarlyOffset2 = hizLod3EarlyOffset * 2;
    hizZWidthOffset     = int(ceil(resolution.x / 2.0));

    atmosphereDriver();
    
    float depth0 = texelFetch(depthtex0, ivec2(gl_FragCoord), 0).r;
    float depth1 = texelFetch(depthtex1, ivec2(gl_FragCoord), 0).r;
    
    
    vec3 sun = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 sunlightColor = atmo_getLightColorAtHeight(200, sun, sunAngle < 0.5, skyLUTtex);
    vec3 fgPos = projectPoint(vec3(gl_FragCoord.xy * resolutionInv, depth0) * 2.0 - 1.0, gbufferProjectionInverse);
    vec3 view = normalize(fgPos);
    
    
    vec3 inscatteringFG = vec3(0);
    vec3 transmittanceFG = vec3(1);
    
    #if DIMENSION == DIM_OVERWORLD
    float cloudDepth = imageLoad(gpbColor0, ivec2(gl_FragCoord)).r;
    if ((-fgPos.z > cloudDepth || depth0 == 1.0) && (isEyeInWater != 1 || depth1 != 1.0)) {
        ivec2 ft = ivec2(gl_FragCoord);
        ft.y += int(resolution.y) * (frameCounter & 1);
        vec4 clouds = texelFetch(colortex8, ft, 0);
        vec3 cloudColor = clouds.x * sunlightColor + clouds.y * averageSkyInscattering;
        
        transmittanceFG *= clouds.b;
        inscatteringFG += cloudColor;
    }
    #endif
    
    // #define REMOVE_FOG
    
    vec3 D = mat3(gbufferModelViewInverse) * view;
    vec3 camera = vec3(0, earthRadius + cameraPosition.y - seaLevel, 0);
    float fgSegmentLength = length(fgPos);
    if (isEyeInWater == 0) {
        #ifndef REMOVE_FOG
        
        #if DIMENSION == DIM_NETHER
        if (depth0 != 1.0) {
            vec3 transmittance;
            inscatteringFG += atmo_getSegmentInscatteringNETHER(cameraPosition, D, fgSegmentLength, 32, transmittance);
            transmittanceFG *= transmittance;
        }
        #endif
        
        #if DIMENSION == DIM_END
        if (depth0 != 1.0) {
            vec3 transmittance;
            inscatteringFG += atmo_getSegmentInscatteringEND(cameraPosition, D, fgSegmentLength, 32, transmittance);
            transmittanceFG *= transmittance;
        }
        #endif
        
        #if DIMENSION == DIM_OVERWORLD
        if (depth0 != 1.0) {
            vec3 transmittance;
            vec3 inscattering = atmo_getSegmentInscatteringShort(camera + D * 100, D, max(0.0, fgSegmentLength - 100), sun, skyLUTtex, transmittance);
            
            transmittanceFG *= transmittance;
            inscatteringFG += inscattering * eyeBrightnessSky;
        }
        
        //inscatteringFG += addGodrays(camera, D, min(fgSegmentLength, 100), sun, skyLUTtex,depth0==1.0, ivec2(gl_FragCoord), isEyeInWater == 1);
        
        float volume;
        if (depth0==1.0) volume = (1.0 - exp(-2.0)) / 2.0;
        else {
            vec2 sunPos = (projectPoint(sunPosition, gbufferProjection) * 0.5 + 0.5).xy * resolution;
            vec2 d = sunPos.xy - gl_FragCoord.xy;
            d /= max(abs(d.x), abs(d.y));
            
            volume = texelFetch(gpbColor2t, ivec2(gl_FragCoord.xy), 0).r;
            vec2 s0 = texelFetch(gpbColor2t, ivec2(gl_FragCoord.xy - d * 2.0), 0).rg;
            vec2 s1 = texelFetch(gpbColor2t, ivec2(gl_FragCoord.xy - d * 1.0), 0).rg;
            vec2 s2 = texelFetch(gpbColor2t, ivec2(gl_FragCoord.xy + d * 1.0), 0).rg;
            vec2 s3 = texelFetch(gpbColor2t, ivec2(gl_FragCoord.xy + d * 2.0), 0).rg;
            
            vec4 vol = vec4(s0.x,s1.x,s2.x,s3.x);
            vec4 len = vec4(s0.y,s1.y,s2.y,s3.y);
            
            vec4 w = step(abs(len - fgSegmentLength), vec4(fgSegmentLength * 0.2));
            
            volume += dot(vol, w);
            volume /= 1.0 + dot(vec4(1), w);
        }
        inscatteringFG += volume * getGodrayColor(camera, D, min(fgSegmentLength, 100), sun, skyLUTtex);
        #endif
        
        #endif
    } else {
        vec2 sunPos = (projectPoint(sunPosition, gbufferProjection) * 0.5 + 0.5).xy * resolution;
        vec2 d = sunPos.xy - gl_FragCoord.xy;
        d /= max(abs(d.x), abs(d.y));
        
        vec2 volume = texelFetch(gpbColor2t, ivec2(gl_FragCoord.xy), 0).rg;
        vec3 s0 = texelFetch(gpbColor2t, ivec2(gl_FragCoord.xy - d * 2.0), 0).rgb;
        vec3 s1 = texelFetch(gpbColor2t, ivec2(gl_FragCoord.xy - d * 1.0), 0).rgb;
        vec3 s2 = texelFetch(gpbColor2t, ivec2(gl_FragCoord.xy + d * 1.0), 0).rgb;
        vec3 s3 = texelFetch(gpbColor2t, ivec2(gl_FragCoord.xy + d * 2.0), 0).rgb;
        
        vec4 len = vec4(s0.z,s1.z,s2.z,s3.z);
        vec4 w = step(abs(len - fgSegmentLength), vec4(fgSegmentLength * 0.2));
        
        volume += s0.xy * w.x + s1.xy * w.y + s2.xy * w.z + s3.xy * w.w;
        volume /= 1.0 + dot(vec4(1), w);
        
        vec3 transmittance;
        vec3 inscattering = volume.xyy * getWaterFogColor(vec3(0), D, fgSegmentLength, sun, ivec2(gl_FragCoord), transmittance);
        transmittanceFG *= transmittance;
        inscatteringFG += inscattering;// * eyeBrightnessSky;
    }
    
    
    if (depth0 != depth1) {
        vec4 albedo = texelFetch(colortex0, ivec2(gl_FragCoord), 0);
        uvec2 wPack = texelFetch(colortex1, ivec2(gl_FragCoord), 0).rg;
        vec3 normal = normalize(octaDecode(unpackSnorm2x16(wPack.x)));
        vec3 trueNormal = normal;
        vec2 lightmap = unpackUnorm2x16(wPack.y);
        if (DIMENSION == DIM_END || DIMENSION == DIM_NETHER) lightmap.y = 1.0;
        bool isWater = albedo.a > 0.5;
        
        float microDetailsBlend = 0.0;
        float thickness = 1.0;
        vec2 mediaInterface = getMediaInterface(isWater);
        
        if (isWater) {
            microDetailsBlend = smoothstep(0.0, 0.5, getPixelSize(depth0));
            normal = getWaterNormal(fgPos, normal, microDetailsBlend);
            float viewZ1 = projectZ(depth1 * 2.0 - 1.0, gbufferProjectionInverse);
            thickness = (fgPos.z - viewZ1) * 2.0;
        }
        fragPosData fragPos0 = fragPosData(vec3(gl_FragCoord.xy, depth0), fgPos, view);
        vec3 bgCoord = getRefractionPosition(fragPos0, normal, trueNormal, mediaInterface.x / mediaInterface.y, thickness);
        vec3 bgPos = projectPoint(bgCoord * 2.0 - 1.0, gbufferProjectionInverse);
        float bgSegmentLength = distance(fgPos, bgPos);
        vec3 absorption = (isWater && isEyeInWater == 0) ? exp(-bgSegmentLength * waterExtinctionCoefficients) : vec3(1);
        
        vec3 solidColor = textureLod(colortex7, bgCoord.xy, 0).rgb;
        
        #if DIMENSION == OVERWORLD
        vec2 ft = bgCoord.xy;
        ft.y = clamp(ft.y, resolutionInv.y * 0.5, 1.0 - resolutionInv.y * 0.5) * 0.5 + 0.5 * (frameCounter & 1);
        vec3 clouds = textureLod(colortex8, ft, 0).rgb;
        vec3 cloudColor = clouds.x * sunlightColor + clouds.y * averageSkyInscattering;
        solidColor *= clouds.b;
        solidColor += cloudColor;
        #endif
        
        vec3 refraction = solidColor * albedo.rgb * absorption;
        vec3 reflection = getReflection(fragPos0, normal, lightmap, microDetailsBlend, sun, ivec2(gl_FragCoord));
        
        float fresnel = fresnel(saturate(dot(normal, -view)), mediaInterface.x, mediaInterface.y);
        
        color.rgb = mix(refraction, reflection, fresnel);
        color.rgb = max(color.rgb, 0.0);
        
    } else {
        color = texelFetch(colortex7, ivec2(gl_FragCoord), 0);
        
        
        // material surface = sampleMaterialNoColor(colortex1, ivec2(gl_FragCoord));
        // vec3 up = gbufferModelView[1].xyz;
        // float slope = dot(surface.normal, up);
        
        // if (slope > 0.9) {
        //     vec3 normal = normalize(mix(surface.normal, up, 0.9));
        //     fragPosData fragPos0 = fragPosData(vec3(gl_FragCoord.xy, depth0), fgPos, view);
            
        //     normal = mix(getWaterNormal(fgPos * 3, normal, 0.0), normal, 0.99);
            
        //     vec3 reflection = getReflection(fragPos0, normal, vec2(1), 0.0, sun);
        
        //     color.rgb = mix(color.rgb, reflection, fresnel(saturate(dot(normal, -view)),1,1.333));
        // }
    }
    
    color.rgb *= transmittanceFG;
    color.rgb += inscatteringFG;
    
    if (any(isnan(color.rgb)) || any(isinf(color.rgb))) color.rgb = vec3(0);  
}

//const bool colortex7MipmapEnabled = true;