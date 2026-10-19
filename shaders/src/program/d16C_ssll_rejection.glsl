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
 
const vec2 workGroupsRender = vec2(1.0, 1.0);
layout (local_size_x = 16, local_size_y = 16) in;

#include "/src/common.glsl"
#include "/src/ssbos/ssbo1-4_ssll.glsl"
#include "/src/utils/random.glsl"
#include "/src/utils/compute_utils.glsl"

uniform int frameCounter;
uniform vec2 resolution;
uniform vec2 resolutionInv;

#include "/src/ray_tracing/ssll.glsl"

layout (r32ui) uniform uimage2D gpbUint0;
layout (r11f_g11f_b10f) uniform image2D colorimg2;


shared uint ssllBitmasksLocal[8];

void main() {
    uint seed = generateSeed(vec3(gl_GlobalInvocationID.xy, frameCounter));

    if (gl_LocalInvocationIndex < 8) ssllBitmasksLocal[gl_LocalInvocationIndex] = 0;
    memoryBarrierShared();
    barrier();
    
    uint groupID = getGroupIndex(gl_WorkGroupID.xy, gl_NumWorkGroups);
    uint threadID = getGlobalInvocationIndex(gl_LocalInvocationIndex, groupID, gl_WorkGroupSize);
    
    if (threadID < resolution.x * resolution.y) {
    
        ivec2 threadCoord = idToCoord(threadID);
        
        
        uint lightOutputScaledP = imageLoad(gpbUint0, threadCoord).x;
        
        float lightWeightQ = unpackHalf2x16(lightOutputScaledP).y;
        uint Q = getQ(pow(lightWeightQ, 0.2));
        float qWeight = getQweight(Q);
        
        
        float wMax = uintBitsToFloat(ssllCounters[1]);
        float wSum = ssllCounters[2] * exp2(-b) + ssllCounters[3] * exp2(32 - b);
        
        
        uint targetCount = uint(resolution.x * resolution.y * targetCoverage);
        float eCount = wSum / wMax;
        
        float P = qWeight / wMax;
        if (eCount > targetCount) P *= targetCount / eCount;
        
        
        uvec2 ldsUV = uvec2(gl_LocalInvocationIndex&31, gl_LocalInvocationIndex>>5);
        
        if (rnd(seed) < P) atomicOr(ssllBitmasksLocal[ldsUV.y], 1u<<ldsUV.x);

    }
    memoryBarrierShared();
    barrier();
    
    // output size: ceil(R / 32.0)
    // max output size: ceil(R / 256.0) * 8
    if (gl_LocalInvocationIndex < 8 && groupID < ceil(resolution.x * resolution.y / 256.0)) {
        uint ID = groupID * 8 + gl_LocalInvocationIndex;
        ssllBitmasks[ID] = ssllBitmasksLocal[gl_LocalInvocationIndex];
    }
    
}