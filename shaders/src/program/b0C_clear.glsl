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

const ivec3 workGroups = ivec3(2, 1, 1);
layout (local_size_x = 32) in;

void clear0();
void clear1();
void main() {   
    if (gl_WorkGroupID.x == 0) clear0();
    if (gl_WorkGroupID.x == 1) clear1();
}

#include "/src/common.glsl"

#include "/properties/shadow_settings.glsl"
#include "/src/utils/shadowmap.glsl"
#include "/src/ssbos/ssbo0_drs.glsl"

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

void clear0() {
    #if DIMENSION == DIM_OVERWORLD
    vec3 positionScreen = vec3(0.0, 0.0, -1.0);
    vec3 position = projectPoint(positionScreen, gbufferProjectionInverse);
    vec3 positionWorld = mat4x3(gbufferModelViewInverse) * vec4(position, 1.0);
    vec3 positionShadowAligned = mat4x3(shadowModelView) * vec4(positionWorld, 1.0);
    vec3 positionShadow = mat4x3(shadowProjection) * vec4(positionShadowAligned, 1.0);
    positionShadow.xy /= getDistortionFactorInv(positionShadow.xy);
    ivec2 positionShadowWindow = ivec2(positionShadow.xy * shadowMapResolution / 2);
    
    
    trCorner = positionShadowWindow + 5;
    blCorner = positionShadowWindow - 5;
    #endif
}

#include "/src/ssbos/ssbo1-4_ssll.glsl"

void clear1() {
    if (gl_LocalInvocationIndex < 5) ssllCounters[gl_LocalInvocationIndex] = 0u;
}