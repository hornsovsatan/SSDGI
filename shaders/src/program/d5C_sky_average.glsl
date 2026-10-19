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

#define OVERWORLD_EXCLUSIVE

const ivec3 workGroups = ivec3(1, 1, 1);
layout (local_size_x = 32, local_size_y = 32) in;

uniform sampler2D skytex;

#include "/src/common.glsl"
#include "/src/ssbos/ssbo6.glsl"

shared vec3 colors[1024];

float pdfInv(float y) {
    y = y * 2.0 - 1.0;
    return M_PI * abs(y) * cos(M_PI * 0.5 * abs(y) * y) / (32.0 * 64.0);
}

void main() {
    vec2 uv = (gl_GlobalInvocationID.xy + 0.5) / 32.0;
    vec3 c0 = textureLod(skytex, uv * vec2(1.0, 0.5) - vec2(0.0, 0.5 / 64.0), 0).rgb;
    vec3 c1 = textureLod(skytex, uv * vec2(1.0, 0.5) + vec2(0.0, 0.5 / 64.0), 0).rgb;
    
    colors[gl_LocalInvocationIndex] = (c0 + c1) * pdfInv(uv.y);
    
    memoryBarrierShared();
    barrier();
    
    if (gl_LocalInvocationIndex < 512)
        colors[gl_LocalInvocationIndex * 2] += colors[gl_LocalInvocationIndex * 2 + 1];
    memoryBarrierShared();
    barrier();
    if (gl_LocalInvocationIndex < 256)
        colors[gl_LocalInvocationIndex * 4] += colors[gl_LocalInvocationIndex * 4 + 2];
    memoryBarrierShared();
    barrier();
    if (gl_LocalInvocationIndex < 128)
        colors[gl_LocalInvocationIndex * 8] += colors[gl_LocalInvocationIndex * 8 + 4];
    memoryBarrierShared();
    barrier();
    if (gl_LocalInvocationIndex < 64)
        colors[gl_LocalInvocationIndex *16] += colors[gl_LocalInvocationIndex *16 + 8];
    memoryBarrierShared();
    barrier();
    if (gl_LocalInvocationIndex < 32)
        colors[gl_LocalInvocationIndex *32] += colors[gl_LocalInvocationIndex *32 +16];
    memoryBarrierShared();
    barrier();
    if (gl_LocalInvocationIndex == 0) {
        vec3 color = vec3(0);
        for (int i = 0; i < 32; i++) {
            color += colors[i * 32];
        }
        
        averageSkyInscattering = color;
    }
}

