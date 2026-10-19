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

const vec2 workGroupsRender = vec2(0.333333, 0.333333);
layout (local_size_x = 16, local_size_y = 16) in;

#include "/src/common.glsl"
#include "/src/uniforms.glsl"
#include "/src/utils/compute_utils.glsl"

#include "/properties/shadow_settings.glsl"
#include "/src/ssbos/ssbo0_drs.glsl"
#include "/src/utils/shadowmap.glsl"
#include "/src/lighting/shadow.glsl"
#include "/src/surface/material.glsl"


layout (rg16) uniform image2D dgbu2img;

void main() {
    shadowSpaceScale = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z * shadowZScale);
    drsScale       = drs_scale;
    drsOffset      = drs_offset;
    drsScaleWindow = drs_scale * 0.5;
    drsOffsetWindow = drs_offset * 0.5 + 0.5;

    ivec2 fragCoord = ivec2(gl_GlobalInvocationID) * 3;
    
    if (!inBoundsTR(fragCoord, resolution)) return;
    
    vec2 wb = vec2(0);
    float depth = texelFetch(depthtex0, fragCoord, 0).r;
    float depth2 = texelFetch(depthtex2, fragCoord, 0).r;
    if (depth != 1.0) {
        vec3 position = projectPoint(vec3((fragCoord + 0.5) * resolutionInv, depth) * 2.0 - 1.0, gbufferProjectionInverse);
        if (depth != depth2) position /= 0.3;
        material surface = sampleMaterialNoColor(colortex1, fragCoord);
        float sss = sampleMaterialSSS(colortex3, fragCoord);
        surface.trueNormal = mat3(gbufferModelViewInverse) * surface.trueNormal;
        
        bool sunlit = (dot(surface.normal, shadowLightPosition) > 0.0 || sss > 0.0);
        if (sunlit)
            wb = amalgamaBlocker(position, surface.trueNormal, sss, ivec2(gl_GlobalInvocationID));
    }
    
    imageStore(dgbu2img, ivec2(gl_GlobalInvocationID), vec4(wb.x / -32.0, wb.y / 65535.0, 0, 0));
}

