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

#include "/src/common.glsl"
#include "/src/uniforms.glsl"
#include "/properties/rt_settings.glsl"

#if HIZ_PIXEL_SIZE == 5
const vec2 workGroupsRender = vec2(0.2, 0.2);
#else
const vec2 workGroupsRender = vec2(0.333333, 0.333333);
#endif
layout (local_size_x = 16, local_size_y = 16) in;



layout(r11f_g11f_b10f) uniform image2D gpbColor2;
uniform sampler2D gpbColor2t;
uniform sampler2D hiZtex;

#include "/src/ray_tracing/ssct.glsl"

void main() {
    ivec2 fragCoord =ivec2(gl_GlobalInvocationID);
    
    vec3 color = blurPass(fragCoord, tileMapping(4), 16, hiZtex, gpbColor2t, colortex3);
    
    fragCoord += tileMapping(5);
    imageStore(gpbColor2, fragCoord, vec4(color, 0));
}