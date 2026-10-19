/*
 * All Rights Reserved
 * 
 * Copyright (c) 2025 lipesto
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

const ivec2 ssllRadius = ivec2(6,6);



const vec2 workGroupsRender = vec2(1.0, 1.0);
layout (local_size_x = 16, local_size_y = 16) in;


shared uvec2 lds[16][16][3];
//shared uvec2 lds1[256];

#include "/src/common.glsl"
#include "/src/uniforms.glsl"
#include "/src/ssbos/ssbo1-4_ssll.glsl"
#include "/src/ssbos/ssbo5_ssll_lights.glsl"
#include "/src/utils/compute_utils.glsl"
#include "/src/utils/random.glsl"
#include "/src/utils/storage.glsl"
#include "/src/surface/material.glsl"
#include "/src/lighting/brdf.glsl"





uniform sampler2D hiZtex;
uniform sampler2D gpbColor1t;
uniform sampler2D gpbColor2t;
uniform sampler2D skytex;

#include "/properties/rt_settings.glsl"
#include "/src/lighting/atmosphere.glsl"
#include "/src/lighting/lightmap.glsl"
#include "/src/ray_tracing/sampling.glsl"
#include "/src/ray_tracing/ssrt.glsl"
#include "/src/ray_tracing/ssct.glsl"

#define SSLL_SAMPLING
#include "/src/ray_tracing/ssll.glsl"









layout (rg32ui) uniform uimage2D colorimg6; //clusters

layout (rgba16f) uniform image2D colorimg4;
layout (rgba16f) uniform image2D colorimg5;
layout (rgba16f) uniform image2D colorimg9;
layout (r11f_g11f_b10f) uniform image2D gpbColor1;

vec2 reprojectViewFlat(vec3 position) {    
    vec4 p = gbufferModelViewInverse * vec4(position, 1);
    vec4 pT = p;
    vec4 pR = p;
    pT.xyz -= (cameraVector) * pT.w;
    pT = gbufferPreviousModelView * pT;
    pT = gbufferPreviousProjection * pT;
    pR.xyz += (mat3(gbufferModelView) * (gbufferModelViewInverse[3].xyz + gbufferPreviousModelView[3].xyz * mat3(gbufferPreviousModelView))) * pR.w;
    pR = gbufferPreviousModelView * pR;
    pR = gbufferPreviousProjection * pR;
    
    vec2 offset = pT.xy/pT.w - pR.xy/pR.w;
    
    return offset * 0.5 * resolution;
}

uvec3 packRadiance(radianceSeparate r) {
    return uvec3(packHalf2x16(r.diffuse.xy), packHalf2x16(r.specular.xy), packHalf2x16(vec2(r.diffuse.z, r.specular.z)));
}

radianceSeparate unpackRadiance(uvec3 p) {
    vec2 t = unpackHalf2x16(p.z);
    return radianceSeparate(vec3(unpackHalf2x16(p.x), t.x), vec3(unpackHalf2x16(p.y), t.y));
}

void main() {
    hizLod2Offset       = ceil(resolution.y / HIZ_PIXEL_SIZE);
    hizLod3Offset       = ceil(resolution.y / HIZ_PIXEL_SIZE) + ceil(resolution.y / HIZ_PIXEL_SIZE / 4.0);
    hizLod3EarlyOffset  = int(ceil(resolution.x / HIZ_PIXEL_SIZE / 16.0));
    hizLod3EarlyOffset2 = hizLod3EarlyOffset * 2;
    hizZWidthOffset     = int(ceil(resolution.x / 2.0));

    uvec2 ldsUV = gl_LocalInvocationID.xy;
    uvec2 centerUV = clamp(gl_WorkGroupID.xy * (ivec2(16, 16) / 4), ivec2(ssllRadius), ivec2(resolution / 4.0 - ssllRadius - 4));
    
    lds[ldsUV.x][ldsUV.y][0] = imageLoad(colorimg6, ivec2(centerUV + gl_LocalInvocationID.xy - ssllRadius) * ivec2(3,1) + ivec2(0,0)).rg;
    lds[ldsUV.x][ldsUV.y][1] = imageLoad(colorimg6, ivec2(centerUV + gl_LocalInvocationID.xy - ssllRadius) * ivec2(3,1) + ivec2(1,0)).rg;
    lds[ldsUV.x][ldsUV.y][2] = imageLoad(colorimg6, ivec2(centerUV + gl_LocalInvocationID.xy - ssllRadius) * ivec2(3,1) + ivec2(2,0)).rg;
    
    memoryBarrierShared();
    barrier();
    ivec2 fragCoord = ivec2(gl_GlobalInvocationID);
    
    if (!inBoundsTR(fragCoord, resolution)) return;
    
    //GBUFFER DATA
    float depth = texelFetch(depthtex0, fragCoord, 0).r;
    if (depth==1.0) return;
    depth -= 1.0/65535.0;
    uvec3 surface = sampleMaterialPacked(colortex0, colortex1, fragCoord);
    vec3 position = projectPoint(vec3((fragCoord + 0.5) * resolutionInv, depth) * 2.0 - 1.0, gbufferProjectionInverse);
    
    uint seed = generateSeed(vec3(fragCoord, frameCounter));
    ssll_LightSource light = ssll_GetLight(position, getNormal(surface), seed);
    
    if (light.uv == fragCoord) light.weight = 0.0;
    
    if (light.weight > 0) {
        #if RAY_PENETRATION
        bool visible = ssrt_CheckVisibilityThickness(vec3(fragCoord + 0.5, depth), vec3(light.uv + 0.5, light.depth));
        #else
        bool visible = ssrt_CheckVisibility(vec3(fragCoord + 0.5, depth), vec3(light.uv + 0.5, light.depth));
        #endif

        #ifdef DISABLE_GI
        visible = true;
        #endif

        if (!visible) light.weight = 0.0;
    }
    
    radianceSeparate radianceSSLL = ssll_ResolveSample(position, light, surface);
    
    
    float roughnessHeuristicSSLL = getRoughnessHeuristic(getRoughness(surface));
    float distanceHeuristicSSLL = exp(-distance(gl_GlobalInvocationID.xy, light.uv)/32);
    
    radianceSSLL.diffuse *= 1.0 - distanceHeuristicSSLL;
    radianceSSLL.specular *= 1.0 - max(distanceHeuristicSSLL, roughnessHeuristicSSLL);
    //lds1[gl_LocalInvocationIndex] = packRadiance(radianceSSLL);
    //uvec3 ssllPack = packRadiance(radianceSSLL) & 0x7FFFFFFF;
    
    
    
    
    raySamplingData raySample = generateDirectionPDF(surface, -normalize(position), fragCoord);
    
    vec4 rayData = ssrt_Ray(position, raySample.direction, vec3(fragCoord + 0.5, depth), getRoughness(surface) < 0.02, 666);
    vec3 hitPosition = projectPoint(rayData.xyz * vec3(resolutionInv, 1.0) * 2.0 - 1.0, gbufferProjectionInverse);
    float t = distance(position, hitPosition);
    if (rayData.z >= 1.0) rayData.a = 0.0;
    rayData.a *= edgeFade(rayData.xy);
    
    vec3 direct = getFilteredEmission(hitPosition, t, getRoughness(surface), rayData.xy, colortex2, gpbColor2t) * rayData.a;
    vec3 indirect = mix(getLightMapContribution(raySample.direction, t, getLightmap(surface), skytex), textureLod(gpbColor1t, rayData.xy * resolutionInv, 0).rgb, rayData.a);
    
    radianceSeparate radianceBRDF = BRDF(raySample.direction, -normalize(position), surface);
    
    float roughnessHeuristicBRDF = getRoughnessHeuristic(getRoughness(surface));
    float distanceHeuristicBRDF = exp(-distance(fragCoord + 0.5, rayData.xy)/8);
    vec2 lpfilter = lowpFilter(getRoughness(surface), raySample.specularProbability, raySample.isSpecular);
    radianceBRDF.diffuse *= (direct * distanceHeuristicBRDF + indirect) / raySample.PDF * lpfilter.x;
    radianceBRDF.specular *= (direct * max(distanceHeuristicBRDF, roughnessHeuristicBRDF) + indirect) / raySample.PDF * lpfilter.y;
    
    //radianceSSLL = unpackRadiance(lds1[gl_LocalInvocationIndex]);
    //radianceSSLL = unpackRadiance(ssllPack);
    radianceSeparate radiance = radianceSeparate(radianceBRDF.diffuse + radianceSSLL.diffuse, radianceBRDF.specular + radianceSSLL.specular);
    
    
    

    
    vec4 diffuse = texelFetch(colortex4, fragCoord, 0);
    vec4 specular = texelFetch(colortex5, fragCoord, 0);
    vec4 moments = texelFetch(colortex9, fragCoord, 0);
    
    vec2 offset = reprojectViewFlat(position);
    
    diffuse.a = min(diffuse.a + 1.0, 16.0);
    specular.a = min(specular.a + 1.0, round(16.0 * getRoughness(surface)) + (exp(-0.5 * length(offset)) * 3.5 + 1.0));
    
    float blendDiffuse = 1.0 / (diffuse.a);
    float blendSpecular = 1.0 / (specular.a);
    
    diffuse.rgb = mix(diffuse.rgb, radiance.diffuse, blendDiffuse);
    specular.rgb = mix(specular.rgb, radiance.specular, blendSpecular);
    
    imageStore(colorimg4, fragCoord, diffuse);
    imageStore(colorimg5, fragCoord, specular);
    
    #if DENOISER == 2
    float diffuseLum = luminance(radiance.diffuse);
    float specularLum = luminance(radiance.specular);
    moments.xy = mix(moments.xy, vec2(diffuseLum, diffuseLum * diffuseLum), blendDiffuse);
    moments.zw = mix(moments.zw, vec2(specularLum, specularLum * specularLum), blendSpecular);
    imageStore(colorimg9, fragCoord, moments);
    #endif
    
}

