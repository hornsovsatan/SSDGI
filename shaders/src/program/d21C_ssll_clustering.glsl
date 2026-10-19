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
 
const vec2 workGroupsRender = vec2(0.25, 0.25);
layout (local_size_x = 32, local_size_y = 32) in;

#include "/src/common.glsl"
#include "/src/ssbos/ssbo1-4_ssll.glsl"
#include "/src/ssbos/ssbo5_ssll_lights.glsl"
#include "/src/utils/compute_utils.glsl"
#include "/src/utils/random.glsl"
#include "/src/utils/storage.glsl"


layout (rg32ui) uniform uimage2D colorimg6;


uniform usampler2D colortex1;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform vec2 resolution;
uniform vec2 resolutionInv;
uniform int frameCounter;


#include "/src/ray_tracing/ssll.glsl"


uint packUnorm3x6Ufloat14x1(vec3 v, float f) {
    uvec3 vu = uvec3(v * 63.0 + 0.5);
    uint fu = packHalf2x16(vec2(f,0)) & 0x3FFF;
    return fu | (vu.x << 14) | (vu.y << 20) | (vu.z << 26);
}


void main() {
    uint seed = generateSeed(vec3(gl_GlobalInvocationID.xy, frameCounter));

    totalBitmasks = uint(ceil(resolution.x * resolution.y / 32.0));
    totalTiles    = (totalBitmasks + 1023u) / 1024u;

    vec3 normalAvg = vec3(0);
    float depthMin = 1.0;
    float depthMax = 0.0;
    
    for (int y = 0; y<4; y++) {
    for (int x = 0; x<4; x++) {
        float d = texelFetch(depthtex0, ivec2(gl_GlobalInvocationID.xy) * 4 + ivec2(x,y), 0).r;
        vec3 n = normalize(octaDecode(unpackSnorm2x16(texelFetch(colortex1, ivec2(gl_GlobalInvocationID.xy) * 4 + ivec2(x,y), 0).r)));
        
        normalAvg += n;
        depthMin = min(depthMin, d);
        depthMax = max(depthMax, d);
    }}
    
    normalAvg /= 16.0;
    
    float normalLength = length(normalAvg);
    
    normalAvg /= normalLength;
    
    vec2 clusterCenter = vec2(gl_GlobalInvocationID.xy + 0.5) * 4.0 * resolutionInv;
    
    vec3 cornerN = vec3(clusterCenter - 1.5 * resolutionInv * fsign(clusterCenter - 0.5), depthMin) * 2.0 - 1.0;
    vec3 cornerF = vec3(clusterCenter + 1.5 * resolutionInv * fsign(clusterCenter - 0.5), depthMax) * 2.0 - 1.0;
    
    cornerN = projectPoint(cornerN, gbufferProjectionInverse);
    cornerF = projectPoint(cornerF, gbufferProjectionInverse);
    
    vec3 sphereCenter = cornerN * 0.5 + cornerF * 0.5;
    float sphereRadius = distance(sphereCenter, cornerF);
    
    
    
    
    
    uint totalLights = ssllCounters[4];
    
    float wsum = 0;
    ssll_lightDataPack rPack;
    float rW = 0;
    
    int N = clusterN;
    for (int i = 0; i<N; i++) {
        uint rndID = uint(rnd(seed) * totalLights);
        
         ivec2 uv = idToCoord(rndID);
        
        ssll_lightDataPack lightPack = ssllLights[rndID];
        
        ivec2 lightUV = ivec2(unpackUvec2(lightPack.uv)); 
        
        vec3 lightNormal = unpackSnorm4x8(lightPack.normal).xyz;
        
        vec2 p = unpackHalf2x16(lightPack.LOSD);
        float lightOutputScaled = p.y;
        float lightDepth = 1.0 - p.x;
        
        vec3 lightPos = projectPoint(vec3((lightUV + 0.5) * resolutionInv, lightDepth) * 2.0 - 1.0, gbufferProjectionInverse);
        

        vec3 L = sphereCenter - lightPos;
        float lengthLInv = inversesqrt(dot(L, L));
        
        vec3 lightDir = L * lengthLInv;
        
        // float cosLight = max(0.0, cos(acos(dot(lightDir, lightNormal)) - asin(min(1.0, sphereRadius * lengthLInv))));
        // float cosSurface = max(0.0, cos(acos(dot(lightDir, -normalAvg)) - asin(min(1.0, sphereRadius * lengthLInv))));
        
        float sinS = min(1.0, sphereRadius * lengthLInv);
        float cosS = sqrt(max(0.0, 1.0 - sinS * sinS));
        
        L *= lengthLInv;
        
        float cosN = max(0.0, dot(-normalAvg, L));
        float sinN = sqrt(max(0.0, 1.0 - cosN * cosN));
        
        float cosL = max(0.0, dot(lightNormal, L));
        float sinL = sqrt(max(0.0, 1.0 - cosL * cosL));
        
        float cosSurface = sinN <= sinS ? 1.0 : (cosN * cosS + sinN * sinS);
        float cosLight =   sinL <= sinS ? 1.0 : (cosL * cosS + sinL * sinS);
        
        
        float sphereCenterDistance = distance(lightPos, sphereCenter);
        
        float lDistance = max(sphereRadius, sphereCenterDistance); 
        
        
        float weightN = mix(1.0, cosSurface, step(0.9, normalLength));
        float weightL = cosLight;
        float weightD =  1.0 / (lDistance * lDistance);
        
        float w = lightOutputScaled * weightN * weightD * weightL;
        
        wsum += w;
        
        if (rnd(seed) < w/wsum || wsum == 0.0) {
            rPack = lightPack;
            rW = w;
        }
        
    }
    //Some data we need to prepare:
    
    //lightPack uv, depth, los, normal, clusterProbability
    //cluster sphere center, sphere radius, avg normal
    
    uint clusterP = ((packHalf2x16(vec2(rW / wsum,0)) + 0x3F) >> 6) & 0xFFFFu;
    
    uint LP0 = rPack.uv;
    uint LP1 = rPack.LOSD;
    uint LP2 = rPack.normal | (uint(normalLength * 255.0) << 24);
    uint LP3 = packHalf2x16(sphereCenter.xy);
    uint LP4 = packHalf2x16(vec2(sphereCenter.z, sphereRadius));
    uint LP5 = packUnorm3x6Ufloat14x1(normalAvg * 0.5 + 0.5, rW / wsum);
    
    
    imageStore(colorimg6, ivec2(gl_GlobalInvocationID) * ivec2(3,1) + ivec2(0, 0), uvec4(LP0, LP1, 0, 0));
    imageStore(colorimg6, ivec2(gl_GlobalInvocationID) * ivec2(3,1) + ivec2(1, 0), uvec4(LP2, LP3, 0, 0));
    imageStore(colorimg6, ivec2(gl_GlobalInvocationID) * ivec2(3,1) + ivec2(2, 0), uvec4(LP4, LP5, 0, 0));
    
    
    //imageStore(colorimg6, ivec2(gl_GlobalInvocationID), uvec4(step(0.9, normalLength) * 512));
    
}

