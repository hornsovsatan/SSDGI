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

const vec2 workGroupsRender = vec2(1.0, 1.0);
layout (local_size_x = 16, local_size_y = 16) in;

#include "/src/common.glsl"
#include "/src/uniforms.glsl"
#include "/src/ssbos/ssbo6.glsl"
#include "/properties/post_settings.glsl"
#include "/src/utils/random.glsl"
#include "/src/post/tonemapping.glsl"

layout (rgba8) uniform image2D colorimg0;




void main() {
    ivec2 fragCoord = ivec2(gl_GlobalInvocationID);
    uint seed = generateSeed(vec3(fragCoord, 0));
    
    vec4 color = texelFetch(colortex7, fragCoord, 0);
    vec3 bloom = textureLod(colortex2, min((fragCoord + 0.5), resolution - 1.0) * 0.5 * resolutionInv, 0).rgb;
    color.rgb = mix(color.rgb, bloom, 0.01 * BLOOM_INTENSITY);
    
    if (rainStrength > 0) {
        vec4 a = texelFetch(colortex0, fragCoord, 0);
        float rainDepth = fract(a.a * 255.0 / 128.0);
        float rainOpacity = float(rainDepth > 0.0) * rainStrength;
        vec3 pptColor = mix(color.rgb, bloom, rainDepth * 8.0);
        pptColor *= 1.0 - rainDepth * 127.0 / 15;
        if (biome_precipitation == 2) {
            pptColor += 1.0 * averageSkyInscattering;
        } else {
            pptColor += 0.1 * averageSkyInscattering;
        }
        color.rgb = mix(color.rgb, pptColor, rainOpacity);
    }
    
    color.rgb *= exp2(EXPOSURE) / (9.6 * Lum);
    color.rgb = TONEMAP_OPERATOR(color.rgb);
    color.rgb = pow(color.rgb, vec3(1.0/2.2));
    color.rgb += rnd(seed) / 255.0;
    
    imageStore(colorimg0, fragCoord, color);
}
