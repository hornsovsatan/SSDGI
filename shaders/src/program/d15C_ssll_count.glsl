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
#include "/src/uniforms.glsl"
#include "/src/ssbos/ssbo1-4_ssll.glsl"
#include "/src/utils/compute_utils.glsl"
#include "/src/ray_tracing/ssll.glsl"

layout (r32ui) uniform uimage2D gpbUint0;

shared uint ssllCountersLocal[4];

void main() {
    if (gl_LocalInvocationIndex < 4) {
        ssllCountersLocal[gl_LocalInvocationIndex] = 0u;
    }
    memoryBarrierShared();
    barrier();
    
    ivec2 threadCoord = ivec2(gl_GlobalInvocationID);   
    
    if (inBoundsTR(threadCoord, resolution)) {
    
        vec3 lightEmission =    texelFetch(colortex2, threadCoord, 0).rgb;
        float lightDepth =      texelFetch(depthtex0, threadCoord, 0).r;
        float width =           min(0.0001, float(texelFetch(colortex3, threadCoord, 0).r >> 16) / float(0xFFFF) / Z_WIDTH_SCALE);
        float area = trapezoidArea(vec3((gl_GlobalInvocationID.xy + 0.5) * resolutionInv, lightDepth) * 2.0 - 1.0, width, gbufferProjectionInverse);
        area = min(area, 0.01);
        
        float lightOutputScaled = dot(lightEmission, vec3(2048)) * area;
        if (lightDepth == 1.0) lightOutputScaled = 0.0;
        
        uint lightOutputScaledP = packHalf2x16(vec2(1.0 - lightDepth, lightOutputScaled)); 
        
        imageStore(gpbUint0, threadCoord, uvec4(lightOutputScaledP));
        
        
        float lightWeightQ = unpackHalf2x16(lightOutputScaledP & 0xFFFF0000u).y; //GPU drivers hate this one simple trick...
        uint Q = getQ(pow(lightWeightQ, 0.2));
        float qWeight = getQweight(Q);
        
        if (qWeight != 0.0) {
            atomicAdd(ssllCountersLocal[0], 1u);
            atomicMax(ssllCountersLocal[1], floatBitsToUint(qWeight));
            uint low = atomicAdd(ssllCountersLocal[2], Q);
            if (low + Q < Q)
                atomicAdd(ssllCountersLocal[3], 1u);
        }
    }
    memoryBarrierShared();
    barrier();
    
    if (gl_LocalInvocationIndex == 0 && ssllCountersLocal[0] != 0) {
        atomicAdd(ssllCounters[0], ssllCountersLocal[0]);
        atomicMax(ssllCounters[1], ssllCountersLocal[1]);
        uint low = atomicAdd(ssllCounters[2], ssllCountersLocal[2]);
        uint carryOut = ssllCountersLocal[3];
        if (low + ssllCountersLocal[2] < ssllCountersLocal[2]) carryOut++;
        atomicAdd(ssllCounters[3], carryOut);
    }
    
    
    
}