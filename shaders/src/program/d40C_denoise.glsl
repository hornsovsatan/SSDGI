/*
 * All Rights Reserved
 * 
 * Copyright (c) 2026 lipesto
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



shared uvec4 lds[28][28];

layout (rgba16f) uniform image2D denoiserCh0;
layout (rgba16f) uniform image2D denoiserCh1;

uniform sampler2D denoiserESt;

vec2 luminance(mat2x3 colors) {
    return vec3(0.2126, 0.7152, 0.0722) * colors;
}

void main() {
    ivec2 localCoord = ivec2(gl_LocalInvocationIndex / gl_WorkGroupSize.y, gl_LocalInvocationIndex % gl_WorkGroupSize.y);
    ivec2 fragCoord = ivec2(gl_WorkGroupID.xy * gl_WorkGroupSize.xy + localCoord);
    
    vec2 variance = vec2(0);
    for (int x = -1; x <= 1; x += 1) {
    for (int y = -1; y <= 1; y += 1) {
        vec4 moments = texelFetch(colortex9, fragCoord + ivec2(x,y), 0);
        vec2 var = clamp(moments.yw - moments.xz * moments.xz, 0.0, 1.0);
        variance += var;
    }}
    variance /= 9.0;
    
    
    
    for (int i = 0; i<4; i++) {
        ivec2 offset = ivec2(i&1, i>>1) * 12;
        
        ivec2 sp = fragCoord + offset - 6;
        vec4 d = texelFetch(colortex4, sp, 0);
        vec4 s = texelFetch(colortex5, sp, 0);
        float z = texelFetch(depthtex0, sp, 0).r;
        vec4 nr = texelFetch(denoiserESt, sp, 0);
        
        uvec4 pack;
        pack.x = packHalf2x16(d.xy);
        pack.y = packHalf2x16(s.xy);
        pack.z = packHalf2x16(vec2(d.z, s.z));
        pack.w = floatBitsToUint(z);
        
        uvec2 ldsUV = localCoord + offset;
        lds[ldsUV.x][ldsUV.y] = pack;
    }
    
    
    barrier();
    
    
    
    
    float zGradient = float((texelFetch(colortex3, fragCoord, 0).r >> 16) + 1) / float(0xFFFF) / Z_WIDTH_SCALE;
    
    uvec2 ldsUV = localCoord + 6;
    uvec4 pack0 = lds[ldsUV.x][ldsUV.y];
    
    vec4 d0 = texelFetch(colortex4, fragCoord, 0);
    vec4 s0 = texelFetch(colortex5, fragCoord, 0);
    float z0 = uintBitsToFloat(pack0.w);
    vec4 nr0 = texelFetch(denoiserESt, fragCoord, 0);
    vec2 l0 =  luminance(mat2x3(d0.rgb, s0.rgb));
    
    if (z0 == 1.0) return;
    
    vec2 lDenom = -1.0 / (vec2(5.0, 6.0) * sqrt(variance + 1e-10));
    
    lDenom *= smoothstep(vec2(12.0, 1.0), vec2(16.0, 2.0), vec2(d0.a, s0.a));
    
    int radius = 6;
    const int stepSize = 2;
    const int level = 1;
    const float kernel[] = {1.0, 0.82, 0.67, 0.15};
    
    vec3 color0 = d0.rgb;
    vec3 color1 = s0.rgb;
    vec2 wsum = vec2(1.0);
    
    for (int x = -radius; x <= radius; x += stepSize) {
    for (int y = -radius; y <= radius; y += stepSize) {
        if(ivec2(x,y) == ivec2(0)) continue;
        ivec2 offset = ivec2(x, y);
        
        ivec2 ldsUV = localCoord + 6 + offset;
        uvec4 pack = lds[ldsUV.x][ldsUV.y];
        vec2 t = unpackHalf2x16(pack.z);
        vec3 d1 = vec3(unpackHalf2x16(pack.x), t.x);
        vec3 s1 = vec3(unpackHalf2x16(pack.y), t.y);
        float z1 = uintBitsToFloat(pack.w);
        vec4 nr1 = texelFetch(denoiserESt, fragCoord + offset, 0);
        vec2 l1 =  vec2(luminance(d1), luminance(s1));
        
        offset = abs(offset);
        
        
        float weightZ = step(abs(z0 - z1), zGradient * (float(offset.x + offset.y) + 0.1));
        float weightK = kernel[offset.x >> level] * kernel[offset.y >> level];
        float weightN = pow(max(dot(nr0.xyz, nr1.xyz), 0.0), 256.0);
        float weightR = step(abs(nr0.w - nr1.w), 0.01);
        vec2 weightL = exp2(abs(l0 - l1) * lDenom);
        
        vec2 weight = weightK * weightZ * weightN * weightL * vec2(1.0, weightR);
        
        color0 += d1 * weight.x;
        color1 += s1 * weight.y;
        
        wsum += weight;
    }}
    
    color0 /= wsum.x;
    color1 /= wsum.y;
    
    
    imageStore(denoiserCh0, fragCoord, vec4(color0, 0));
    imageStore(denoiserCh1, fragCoord, vec4(color1, 0));
}