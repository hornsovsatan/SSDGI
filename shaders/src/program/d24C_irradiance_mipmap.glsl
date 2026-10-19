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

#include "/src/common.glsl"
#include "/src/uniforms.glsl"
#include "/properties/rt_settings.glsl"


#if HIZ_PIXEL_SIZE == 5
layout (local_size_x = 20, local_size_y = 40) in;
shared uvec2 lds[20][40];
#else
layout (local_size_x = 24, local_size_y = 24) in;
shared uvec2 lds[24][24];
#endif

layout(r11f_g11f_b10f) uniform image2D gpbColor2;



void main() {
    #if HIZ_PIXEL_SIZE == 5
    ivec2 localCoord = ivec2(gl_LocalInvocationID);
    #else
    uvec2 tile = uvec2((gl_LocalInvocationIndex / 64) % 3, gl_LocalInvocationIndex / 192) * 8;
    uvec2 local = uvec2(gl_LocalInvocationIndex % 8, (gl_LocalInvocationIndex % 64) / 8);
    ivec2 localCoord = ivec2(tile + local);
    #endif
    
    
    
    ivec2 fragCoord =ivec2(gl_WorkGroupID * gl_WorkGroupSize) + localCoord;
    
    
    float depth = texelFetch(depthtex0, fragCoord, 0).r;
    vec3 color = texelFetch(colortex2, fragCoord, 0).rgb;
    
    lds[localCoord.x][localCoord.y] = uvec2(packHalf2x16(color.rg), packHalf2x16(vec2(color.b, 1.0 - depth)));
    
    barrier();
    
    const ivec2 writeSize = ivec2(gl_WorkGroupSize) / HIZ_PIXEL_SIZE;
    const int radius = HIZ_PIXEL_SIZE/2;
    
    if (localCoord.x < writeSize.x && localCoord.y < writeSize.y) {
        ivec2 uv = localCoord * HIZ_PIXEL_SIZE + HIZ_PIXEL_SIZE/2;
        ivec2 fragCoord = ivec2(gl_WorkGroupID * gl_WorkGroupSize) / HIZ_PIXEL_SIZE * HIZ_PIXEL_SIZE + uv;
        
        uvec2 p = lds[uv.x][uv.y];
        vec4 s0 = vec4(unpackHalf2x16(p.x), unpackHalf2x16(p.y));
        float zwidth = float(texelFetch(colortex3, fragCoord, 0).r >> 16) / (float(0xFFFF) * Z_WIDTH_SCALE) + 0.002;
        
        vec3 color = s0.rgb;
        float wsum = 1.0;
        for (int x = -radius; x<=radius; x++) {
        for (int y = -radius; y<=radius; y++) {
        if (x==0 && y==0) continue;
            uvec2 p = lds[uv.x][uv.y];
            vec4 s1 = vec4(unpackHalf2x16(p.x), unpackHalf2x16(p.y));
            float w = step(abs(s1.w - s0.w), (abs(x) + abs(y)) * zwidth);
            color += s1.rgb * w;
            wsum += w;
        }}
        color /= wsum;
        
        imageStore(gpbColor2, fragCoord / HIZ_PIXEL_SIZE, vec4(color, 0));
    }
}

