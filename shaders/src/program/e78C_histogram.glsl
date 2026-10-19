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

const ivec3 workGroups = ivec3(1, 1, 1);
layout (local_size_x = 32, local_size_y = 32) in;

#include "/src/ssbos/ssbo6.glsl"
#include "/properties/post_settings.glsl"

uniform vec2 resolution;
uniform int frameCounter;
uniform float frameTime;

shared uint lds[1024];


void main() {
    uint count = histogram[gl_LocalInvocationIndex];
    lds[gl_LocalInvocationIndex] = count * gl_LocalInvocationIndex;
    barrier();
    
    histogram[gl_LocalInvocationIndex] = 0u;
    
    for (uint cutoff = (1024 >> 1); cutoff > 0; cutoff >>= 1) {
        if (gl_LocalInvocationIndex < cutoff) 
            lds[gl_LocalInvocationIndex] += lds[gl_LocalInvocationIndex + cutoff];
        
        barrier();
    }
    
    if (gl_LocalInvocationIndex == 0) {
        
        if (frameCounter < 3) Lum = 0.01;
        
        float weightedLogAverage = (lds[0] / max(floor(resolution.x * resolution.y * 0.25) - count, 1.0)) - 1.0;
        float weightedAvgLum = exp2(((weightedLogAverage / 1022.0) * exposureRange) + exposureLowBound);
        
        float a = 1.0 - exp(-frameTime / eyeAdaptationTime);
        
        Lum = mix(Lum, weightedAvgLum, a);
    }
}

