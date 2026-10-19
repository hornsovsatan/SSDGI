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
#include "/src/surface/material.glsl"
#include "/src/surface/reprojection.glsl"
#include "/properties/rt_settings.glsl"

layout (r11f_g11f_b10f) uniform image2D gpbColor1;
layout (rgba8_snorm) uniform image2D denoiserES;

#if DENOISER == 2
/* RENDERTARGETS: 4,5,9 */
layout(location = 0) out vec4 diffuse;
layout(location = 1) out vec4 specular;
layout(location = 2) out vec4 moments;
#else
/* RENDERTARGETS: 4,5 */
layout(location = 0) out vec4 diffuse;
layout(location = 1) out vec4 specular;
#endif
void main() {
    float depth = texelFetch(depthtex0, ivec2(gl_FragCoord), 0).r;
    float depth2 = texelFetch(depthtex2, ivec2(gl_FragCoord), 0).r;
    vec3 position = projectPoint(vec3(gl_FragCoord.xy * resolutionInv, depth) * 2.0 - 1.0, gbufferProjectionInverse);
    
    material surface = sampleMaterialNoColor(colortex1, ivec2(gl_FragCoord));
    
    mat3x4 ghostBuster = reproject(position, surface, colortex4, colortex5, colortex9, colortex6, false);
    
    diffuse = ghostBuster[0]; if (any(isnan(diffuse))) diffuse = vec4(0.0);
    specular = ghostBuster[1]; if (any(isnan(specular))) specular = vec4(0.0);
    
    #if DENOISER == 2
    moments = ghostBuster[2]; 
    if (any(isnan(moments.xy))) moments.xy = vec2(0.0);
    if (any(isnan(moments.zw))) moments.zw = vec2(0.0);
    #endif
    
    vec3 albedo = pow(texelFetch(colortex0, ivec2(gl_FragCoord), 0).rgb, vec3(2.2));
    vec3 irradiance = albedo * diffuse.rgb + specular.rgb * surface.roughness;
    imageStore(gpbColor1, ivec2(gl_FragCoord), vec4(irradiance, 0));
    #if DENOISER > 0
    imageStore(denoiserES, ivec2(gl_FragCoord), vec4(surface.normal, surface.roughness));
    #endif
}