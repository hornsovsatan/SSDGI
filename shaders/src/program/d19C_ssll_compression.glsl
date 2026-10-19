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


#include "/src/ssbos/ssbo1-4_ssll.glsl"
#include "/src/ssbos/ssbo5_ssll_lights.glsl"
#include "/src/utils/compute_utils.glsl"
#include "/src/utils/storage.glsl"


layout (r32ui) uniform uimage2D gpbUint0;

uniform sampler2D depthtex0;
uniform usampler2D colortex1;
uniform vec2 resolution;
uniform vec2 resolutionInv;

#include "/src/ray_tracing/ssll.glsl"


uint packUvec2(uvec2 v) {
    return v.x | (v.y << 16);
}

layout (rgba8) uniform image2D colorimg9;
void main() {
    uint groupID = getGroupIndex(gl_WorkGroupID.xy, gl_NumWorkGroups);
    uint threadID = getGlobalInvocationIndex(gl_LocalInvocationIndex, groupID, gl_WorkGroupSize);
    
    if (threadID >= resolution.x * resolution.y) return;
    
    
    
    uint bitmaskID = threadID / 32;
    uint batchOffset = bitmaskID % 1024 == 0 ? 0 : ssllSums[bitmaskID - 1];
    
    
    uint tileID = bitmaskID / 1024;
    uint tileOffset = tileID == 0 ? 0 : ssllTileSums[tileID - 1];
    
    uint bitmask = ssllBitmasks[bitmaskID];
    
    uint bitID = threadID % 32;
    uint bitOffset = bitCount(bitmask << (31 - bitID));
    
    //Presistance check
    if (!bool((bitmask >> bitID) & 1u)) return;
    
    
    ivec2 threadCoord = idToCoord(threadID, resolution);
    
    uint lightUV = packUvec2(threadCoord);
    uint LOSD = imageLoad(gpbUint0, threadCoord).r;
    uint lightNormal = packSnorm4x8(vec4(normalize(octaDecode(unpackUnorm4x8(texelFetch(colortex1, threadCoord, 0).y).xy * 2.0 - 1.0)), 0));
    ssllLights[tileOffset + batchOffset + bitOffset - 1] = ssll_lightDataPack(lightUV, LOSD, lightNormal);
    
    imageStore(colorimg9, threadCoord, vec4(1));
}