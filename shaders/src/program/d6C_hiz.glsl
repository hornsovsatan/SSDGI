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

#include "/src/common.glsl"
#include "/src/uniforms.glsl"
#include "/properties/rt_settings.glsl"


#if HIZ_PIXEL_SIZE == 5
const vec2 workGroupsRender = vec2(0.2, 0.2);
#else
const vec2 workGroupsRender = vec2(0.333333, 0.333333);
#endif
layout (local_size_x = 16, local_size_y = 16) in;

shared uint depthMax[4][4];
shared uint depthMin[4][4];
shared uint backdepthMax[4][4];


layout (r32f) uniform image2D hiZimg;

void main() {
    float hizLod2Offset     = ceil(resolution.y / HIZ_PIXEL_SIZE);
    float hizLod3Offset     = ceil(resolution.y / HIZ_PIXEL_SIZE) + ceil(resolution.y / HIZ_PIXEL_SIZE / 4.0);
    int hizLod3EarlyOffset  = int(ceil(resolution.x / HIZ_PIXEL_SIZE / 16.0));
    int hizLod3EarlyOffset2 = hizLod3EarlyOffset * 2;
    int hizZWidthOffset   = int(ceil(resolution.x / 2.0));
    vec2 lod1Resolution = ceil(resolution / HIZ_PIXEL_SIZE);
    vec2 lod2Resolution = ceil(lod1Resolution / 4);
    vec2 lod3Resolution = ceil(lod2Resolution / 4);
    
    if (gl_LocalInvocationIndex < 16) {
        depthMin[gl_LocalInvocationIndex & 3][gl_LocalInvocationIndex >> 2] = floatBitsToUint(1.0);
        depthMax[gl_LocalInvocationIndex & 3][gl_LocalInvocationIndex >> 2] = floatBitsToUint(0.0);
        backdepthMax[gl_LocalInvocationIndex & 3][gl_LocalInvocationIndex >> 2] = floatBitsToUint(0.0);
    }
    
    memoryBarrierShared();
    barrier();
    
    if (all(lessThan(gl_GlobalInvocationID.xy, lod1Resolution))) {
        ivec2 uv = min(ivec2(gl_GlobalInvocationID) * HIZ_PIXEL_SIZE + HIZ_PIXEL_SIZE/2, ivec2(resolution - 1.0));
        float depth = texelFetch(depthtex0, uv, 0).r;
        float zwidth = float(texelFetch(colortex3, uv, 0).r >> 16) / (float(0xFFFF) * Z_WIDTH_SCALE) * HIZ_PIXEL_SIZE + 0.00004;
        //zwidth = max(zwidth, getThickness());
        float backdepth = depth + zwidth;
        
        imageStore(hiZimg, ivec2(gl_GlobalInvocationID), vec4(depth));
        imageStore(hiZimg, ivec2(gl_GlobalInvocationID) + ivec2(hizZWidthOffset, 0), vec4(backdepth));
    
        uvec2 ldsUV = gl_LocalInvocationID.xy >> 2;
        uint iDepth = floatBitsToUint(depth);
        uint iBackdepth = floatBitsToUint(backdepth * 2.0);
        
        atomicMin(depthMin[ldsUV.x][ldsUV.y], iDepth);
        atomicMax(depthMax[ldsUV.x][ldsUV.y], iDepth);
        if (depth != 1.0)
            atomicMax(backdepthMax[ldsUV.x][ldsUV.y], iBackdepth);
    }
    
    memoryBarrierShared();
    barrier();
    
    if (gl_LocalInvocationIndex < 16) {
        ivec2 localUV = ivec2(gl_LocalInvocationIndex & 3, gl_LocalInvocationIndex >> 2);
        ivec2 uv = ivec2(gl_WorkGroupID) * 4 + localUV;
        
        if (all(lessThan(uv, lod2Resolution))) {
            uint iDepthMin = depthMin[localUV.x][localUV.y];
            uint iDepthMax = depthMax[localUV.x][localUV.y];
            uint iBackdepth = backdepthMax[localUV.x][localUV.y];
            imageStore(hiZimg, uv + ivec2(0, hizLod2Offset), vec4(uintBitsToFloat(iDepthMin)));
        
            atomicMin(depthMin[0][0], iDepthMin);
            atomicMax(depthMax[0][0], iDepthMax);
            atomicMax(backdepthMax[0][0], iDepthMax); 
        }
    }
    
    memoryBarrierShared();
    barrier();
    
    if (gl_LocalInvocationIndex == 0) {
        ivec2 uv = ivec2(gl_WorkGroupID);
        if (all(lessThan(uv, lod3Resolution))) {
            imageStore(hiZimg, uv + ivec2(0, hizLod3Offset), vec4(uintBitsToFloat(depthMin[0][0])));
            imageStore(hiZimg, uv + ivec2(hizLod3EarlyOffset, hizLod3Offset), vec4(uintBitsToFloat(depthMax[0][0])));
            imageStore(hiZimg, uv + ivec2(hizLod3EarlyOffset2, hizLod3Offset), vec4(uintBitsToFloat(backdepthMax[0][0])));
        }
    }
}