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
 
const ivec3 workGroups = ivec3(1, 1, 1);
layout (local_size_x = 1024) in;

#include "/src/ssbos/ssbo1-4_ssll.glsl"
#include "/src/utils/compute_utils.glsl"

uniform vec2 resolution;
uniform vec2 resolutionInv;

#include "/src/ray_tracing/ssll.glsl"


shared uint lds[1024];

void main() {
    totalBitmasks = uint(ceil(resolution.x * resolution.y / 32.0));
    totalTiles    = (totalBitmasks + 1023u) / 1024u;

    lds[gl_LocalInvocationIndex] = gl_LocalInvocationIndex < totalTiles ? ssllSums[gl_LocalInvocationIndex * 1024 + 1023] : 0;
    
    barrier();
    
    if (gl_LocalInvocationIndex == 0) {
        uint sum = 0;
        for (int i = 0; i<totalTiles; i++) {
            sum += lds[i];
            lds[i] = sum;
        }
        
        ssllCounters[4] = sum;
    }
    
    barrier();
    
    
    ssllTileSums[gl_LocalInvocationIndex] = lds[gl_LocalInvocationIndex];
    
}