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

#define OVERWORLD_EXCLUSIVE

const vec2 workGroupsRender = vec2(1.0, 1.0);
layout (local_size_x = 16, local_size_y = 16) in;

#include "/src/common.glsl"
#include "/src/uniforms.glsl"

#include "/src/ssbos/ssbo0_drs.glsl"
#include "/properties/shadow_settings.glsl"
#include "/src/utils/shadowmap.glsl"
#include "/src/lighting/shadow.glsl"
#define ATMOSPHERE_SHADOWMAPPING
#include "/src/lighting/atmosphere.glsl"


layout(r11f_g11f_b10f) uniform image2D gpbColor2;
uniform sampler2D gpbColor2t;
uniform sampler2D skyLUTtex;




layout (rgba8) uniform image2D colorimg0;



void main() {
    shadowSpaceScale = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z * shadowZScale);
    drsScale       = drs_scale;
    drsOffset      = drs_offset;
    drsScaleWindow = drs_scale * 0.5;
    drsOffsetWindow = drs_offset * 0.5 + 0.5;

    ivec2 fragCoord = ivec2(gl_GlobalInvocationID);
    
    float depth = texelFetch(depthtex0, fragCoord, 0).r;
    vec3 store;
    if (depth != 1.0 || isEyeInWater != 0) {
        vec3 position = projectPoint(vec3((fragCoord + 0.5) * resolutionInv, depth) * 2.0 - 1.0, gbufferProjectionInverse);
        vec3 view = mat3(gbufferModelViewInverse) * normalize(position);
        position *= 0.98;
        
        
        float segmentLength = min(length(position), isEyeInWater == 0 ? 100.0 : 50.0);
        
        vec3 O = worldToShadowAlignedSpace(gbufferModelViewInverse[3].xyz);
        O.z -= 0.1;
        vec3 D = mat3(shadowModelView) * view;
        vec3 F = O + D * segmentLength;
        //F.z -= 0.3;
        
        float rand = blueNoiseScalar(ivec3(fragCoord, frameCounter&3));
        
        int steps = 6;
        
        if (isEyeInWater == 0) {
            float vol = 0.0;
            for (int i = 0; i<steps; i++) {
                float t = (i + rand) / steps;
                vec3 wP = mix(O, F, t);
                
                float v = sampleShadowMapTest(wP);
                
                float density = exp(-t * segmentLength / 50.0);
                
                vol += v * density;
            }
            vol /= steps;
            store = vec3(vol, segmentLength, 0);
        } else {
            vec2 vol = vec2(0.0);
            for (int i = 0; i<steps; i++) {
                float t = (i + rand) / steps;
                vec3 wP = mix(O, F, t);
                
                vec2 shadow = sampleShadowMapTestOq(wP);
                
                float x = t * segmentLength;
                vec2 tr = exp(-x * waterExtinctionCoefficients.xy);
                
                vec2 lightAttenuation = exp(-max(0.0, -wP.z + shadow.y) * waterExtinctionCoefficients.xy);
                
                vol += shadow.x * tr * lightAttenuation;
            }
            vol /= steps;
            store = vec3(vol, segmentLength);
        }
        
        
    } else {
        float vol = (1.0 - exp(-2.0)) / 2.0;
        store = vec3(vol, 100, 0);
    }
    
    imageStore(gpbColor2, fragCoord, vec4(store,0));
}

