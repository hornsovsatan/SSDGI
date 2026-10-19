/*
 * All Rights Reserved
 * 
 * Copyright (c) 2025-2026 jbritain & lipesto
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
#include "/src/lighting/atmosphere.glsl"
#include "/src/lighting/clouds.glsl"

layout(r11f_g11f_b10f) uniform image2D gpbColor0;
layout(r11f_g11f_b10f) uniform image2D colorimg2;


void main() {
    atmosphereDriver();
    ivec2 fragCoord = ivec2(gl_GlobalInvocationID);
    
    float depth = texelFetch(depthtex1, fragCoord, 0).r;
    vec3 position = projectPoint(vec3((fragCoord + 0.5) * resolutionInv, depth) * 2.0 - 1.0, gbufferProjectionInverse);
    vec3 sun = mat3(gbufferModelViewInverse) * normalize(shadowLightPosition);
    vec3 view = mat3(gbufferModelViewInverse) * normalize(position);
    
    float maxCloudDistance = depth == 1.0 ? 1e6 : length(position);
    vec2 cloudSegmentEnds = getRayBoundaries(view, maxCloudDistance);
    
    vec3 clouds = vec3(0.0, 0.0, 1.0);
    float closestHit = 0.0;
    if (cloudSegmentEnds.x != cloudSegmentEnds.y)
        clouds = getCloudSegment(
            view, 
            cloudSegmentEnds, 
            sun, 
            closestHit, 
            vec2(
                blueNoiseScalar(ivec3(fragCoord, frameCounter)),
                blueNoiseScalar(ivec3(fragCoord, frameCounter + 16))
            )
        );
    
    bool intersectedCloudVolume = (cloudSegmentEnds.x != cloudSegmentEnds.y);
    
    imageStore(gpbColor0, fragCoord, vec4(closestHit.xx, intersectedCloudVolume, 0));
    imageStore(colorimg2, fragCoord, vec4(clouds, 0));
}