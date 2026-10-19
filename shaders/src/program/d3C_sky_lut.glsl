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

const ivec3 workGroups = ivec3(16, 16, 1);
layout (local_size_x = 8, local_size_y = 8) in;

layout (rgba8) uniform image2D skyLUTimg;

#include "/src/common.glsl"
#include "/src/uniforms.glsl"
#include "/src/lighting/atmosphere.glsl"


void main() {
    atmosphereDriver();
    vec3 attenuation = atmo_computeAttenuation(vec2(gl_GlobalInvocationID.xy + 0.5) / 128.0);
    
    imageStore(skyLUTimg, ivec2(gl_GlobalInvocationID), vec4(attenuation, 0));
}

