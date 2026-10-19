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

#include "/src/common.glsl"
#include "/src/uniforms.glsl"
#include "/properties/shadow_settings.glsl"
#include "/src/ssbos/ssbo0_drs.glsl"
#include "/src/utils/shadowmap.glsl"

const vec2 workGroupsRender = vec2(0.5, 0.5);
layout (local_size_x = 16, local_size_y = 16) in;


shared ivec2 trCornerLocal;
shared ivec2 blCornerLocal;


void main() {   
    vec3 shadowSpaceScale = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z * shadowZScale);

    if (gl_LocalInvocationIndex == 0u) {
        trCornerLocal = ivec2(-shadowMapResolution / 2);
        blCornerLocal = ivec2( shadowMapResolution / 2);
    }
    
    memoryBarrierShared();
    barrier();
    
    
    ivec2 uv = min(ivec2(gl_GlobalInvocationID) * 2, ivec2(resolution - 1.0));
    float depth = texelFetch(depthtex1, uv, 0).r;
    
    vec3 positionScreen = vec3(vec2(gl_GlobalInvocationID.xy * 2 + 0.5) * resolutionInv, depth) * 2.0 - 1.0;
    
    vec3 position = projectPoint(vec3(vec2(gl_GlobalInvocationID.xy * 2 + 0.5) * resolutionInv, depth) * 2.0 - 1.0, gbufferProjectionInverse);
    vec3 positionWorld = mat4x3(gbufferModelViewInverse) * vec4(position, 1.0);
    vec3 positionShadowAligned = mat4x3(shadowModelView) * vec4(positionWorld, 1.0);
    
    vec3 positionShadow = positionShadowAligned * shadowSpaceScale;
    positionShadowAligned.z += shadowProjection[3].z / shadowZScale;
    
    
    vec3 chunkPos = floor(positionWorld / 16.0 + fract(cameraPosition / 16));
    const float shadowRadius = shadowDistanceRenderMul * 8.0;
    bool chunkMask = chunkPos == clamp(chunkPos, -shadowRadius, shadowRadius);
    
    if (depth != 1.0 && chunkMask) {
        
        vec2 blCornerShadow = positionShadow.xy - maxPenumbraSize * shadowSpaceScale.xy;
        vec2 trCornerShadow = positionShadow.xy + maxPenumbraSize * shadowSpaceScale.xy;
        blCornerShadow.xy /= getDistortionFactorInv(blCornerShadow.xy);
        trCornerShadow.xy /= getDistortionFactorInv(trCornerShadow.xy);
    
        ivec2 blCornerShadowWindow = ivec2(blCornerShadow.xy * shadowMapResolution / 2);
        ivec2 trCornerShadowWindow = ivec2(trCornerShadow.xy * shadowMapResolution / 2);
        
        atomicMin(blCornerLocal.x, blCornerShadowWindow.x);
        atomicMin(blCornerLocal.y, blCornerShadowWindow.y);
        atomicMax(trCornerLocal.x, trCornerShadowWindow.x);
        atomicMax(trCornerLocal.y, trCornerShadowWindow.y);
    }
    
    
    
    memoryBarrierShared();
    barrier();
    
    if (gl_LocalInvocationIndex == 0u) {
        atomicMin(blCorner.x, blCornerLocal.x);
        atomicMin(blCorner.y, blCornerLocal.y);
        atomicMax(trCorner.x, trCornerLocal.x);
        atomicMax(trCorner.y, trCornerLocal.y);
    }
}
