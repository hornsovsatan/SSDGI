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
#include "/properties/buffer_settings.glsl"
#include "/properties/rt_settings.glsl"
#include "/src/surface/material.glsl"
#include "/src/lighting/atmosphere.glsl"

uniform sampler2D skytex;
uniform sampler2D skyLUTtex;
uniform sampler2D moontex;

uniform sampler2D denoiserCh0t;
uniform sampler2D denoiserCh1t;

#include "/src/lighting/space.glsl"
#include "/src/lighting/brdf.glsl"


layout (r11f_g11f_b10f) uniform image2D gpbColor0;
layout (rgba8) uniform image2D colorimg0;
layout (rgba16f) uniform image2D colorimg7;
layout (rg32ui) uniform uimage2D colorimg6;

// /* RENDERTARGETS: 0,7,6 */
// layout(location = 0) out vec4 clearBuffer0;
// layout(location = 1) out vec4 color;
// layout(location = 2) out uvec2 geometry;
void main() {
    atmosphereDriver();
    ivec2 fragCoord = ivec2(gl_GlobalInvocationID);
    
    float depth = texelFetch(depthtex0, fragCoord, 0).r;
    vec3 position = projectPoint(vec3((fragCoord + 0.5) * resolutionInv, depth) * 2.0 - 1.0, gbufferProjectionInverse);
    
    material surface;
    uvec2 geometry;
    if (depth == 1.0) {
        geometry = packGeometryData(0.0, vec3(0, 0, -1), 0.0);
    } else {
        surface = sampleMaterial(colortex0, colortex1, fragCoord);
        geometry = packGeometryData(position.z, surface.normal, surface.roughness);
    }
    imageStore(colorimg6, fragCoord, uvec4(geometry, 0, 0));
    imageStore(colorimg0, fragCoord, vec4(1,1,1,0));
    
    vec4 color = vec4(0);
    if (depth == 1.0) {
        vec3 D = mat3(gbufferModelViewInverse) * normalize(position);
        vec3 sun = mat3(gbufferModelViewInverse) * normalize(sunPosition);
        
        color.rgb = getSkyColor(D, sun, sunAngle, skytex);
    } else {
        vec3 sunSpecular = imageLoad(gpbColor0, fragCoord).rgb;
        
        
        #if DENOISER > 0
        vec3 diffuse = texelFetch(denoiserCh0t, fragCoord, 0).rgb;
        vec3 specular = texelFetch(denoiserCh1t, fragCoord, 0).rgb;
        #else
        vec3 diffuse = texelFetch(colortex4, fragCoord, 0).rgb;
        vec3 specular = texelFetch(colortex5, fragCoord, 0).rgb;
        #endif
        vec3 emission = texelFetch(colortex2, fragCoord, 0).rgb;
        
        color.rgb  = diffuse * surface.albedo;
        color.rgb += specular;
        color.rgb += sunSpecular;
        color.rgb += emission;
        
        if (any(isnan(color.rgb)) || any(isinf(color.rgb))) color.rgb = vec3(0);  
    }
    
    imageStore(colorimg7, fragCoord, color);
}