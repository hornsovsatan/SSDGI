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


const vec2 workGroupsRender = vec2(0.5, 0.5);
layout (local_size_x = 32, local_size_y = 32) in;

uniform vec2 resolution;
uniform vec2 resolutionInv;

uniform sampler2D colortex7;
layout (r11f_g11f_b10f) uniform image2D colorimg2;

#include "/src/ssbos/ssbo6.glsl"
#include "/src/utils/compute_utils.glsl"
#include "/properties/post_settings.glsl"

shared uint lds[1024];

uint colorToBin(vec3 hdrColor, float minLogLum, float inverseLogLumRange) {
  float lum = dot(hdrColor, vec3(0.2125, 0.7154, 0.0721));

  if (lum < 0.00001)
    return 0;

  float logLum = clamp((log2(lum) - minLogLum) * inverseLogLumRange, 0.0, 1.0);

  return uint(logLum * 1022.0 + 1.0);
}

void main() {
    ivec2 fragCoord = ivec2(gl_GlobalInvocationID);
    vec2 uv = vec2(fragCoord + 0.5) * 2.0 * resolutionInv;
    vec3 color = textureLod(colortex7, uv, 0).rgb;
    imageStore(colorimg2, fragCoord, vec4(color / 6.0, 0));
    
    lds[gl_LocalInvocationIndex] = 0;
    barrier();
    
    if (inBoundsTR(ivec2(gl_GlobalInvocationID), floor(resolution * 0.5))) {
        vec2 uv = (gl_GlobalInvocationID.xy + 0.5) * 2.0 * resolutionInv;
        vec3 c0 = textureLod(colortex7, uv, 0).rgb;
        
        uint binIndex = colorToBin(c0, exposureLowBound, 1.0 / exposureRange);
        atomicAdd(lds[binIndex], 1u);
    }
    
    barrier();
    
    atomicAdd(histogram[gl_LocalInvocationIndex], lds[gl_LocalInvocationIndex]);
}