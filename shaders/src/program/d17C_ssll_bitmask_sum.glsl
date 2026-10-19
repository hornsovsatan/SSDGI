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
 
const vec2 workGroupsRender = vec2(0.125, 0.25);
layout (local_size_x = 32, local_size_y = 32) in;



#include "/src/ssbos/ssbo1-4_ssll.glsl"
#include "/src/utils/compute_utils.glsl"

uniform vec2 resolution;
uniform vec2 resolutionInv;

#include "/src/ray_tracing/ssll.glsl"

shared uint lds[1025];

void main() {
    totalBitmasks = uint(ceil(resolution.x * resolution.y / 32.0));
    totalTiles    = (totalBitmasks + 1023u) / 1024u;

    uint groupID = getGroupIndex(gl_WorkGroupID.xy, gl_NumWorkGroups);
    uint threadID = getGlobalInvocationIndex(gl_LocalInvocationIndex, groupID, gl_WorkGroupSize);
    
    if (groupID >= totalTiles) return;
    
    uint bitmask = threadID < totalBitmasks ? ssllBitmasks[threadID].r : 0;
    
    uint count = bitCount(bitmask);
    
    lds[gl_LocalInvocationIndex] = count;
    
    memoryBarrierShared();
    barrier();
    
    const uint keys = 1024;
    const uint h = keys / 2;
    const uint n = findMSB(keys);
    
    for (int i = 0; i < n; i++) {
        uint offset = 1 << i;
        uint size = h >> i;
        memoryBarrierShared();
        barrier();
        if (gl_LocalInvocationIndex < size) {
            uint ai = offset * (2 * gl_LocalInvocationIndex + 1) - 1;
            uint bi = offset * (2 * gl_LocalInvocationIndex + 2) - 1;
            
            lds[bi] += lds[ai];
        }
        offset *= 2;
        
    }
    
    memoryBarrierShared();
    barrier();
    if (gl_LocalInvocationIndex == 0) {
        lds[keys] = lds[keys-1];
        lds[keys-1] = 0;
    }
    
    for (int i = 0; i < 10; i++) {
        uint offset = h >> i;
        uint size = 1 << i;
        memoryBarrierShared();
        barrier();
        if (gl_LocalInvocationIndex < size) {
            uint ai = offset * (2 * gl_LocalInvocationIndex + 1) - 1;
            uint bi = offset * (2 * gl_LocalInvocationIndex + 2) - 1;
            
            uint t = lds[ai];
            lds[ai] = lds[bi];
            lds[bi] += t;
            
        }
    }
    
    memoryBarrierShared();
    barrier();
    
    //tile size: 1024
    //Always output whole tile
    ssllSums[threadID] = lds[gl_LocalInvocationIndex+1];
}

//Total tiles = ceil(R / 1024)