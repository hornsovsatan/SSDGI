/*
 * All Rights Reserved
 * 
 * Copyright (c) 2025 jbritain & lipesto
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
layout (local_size_x = 8, local_size_y = 8) in;

#include "/src/common.glsl"
#include "/src/uniforms.glsl"

const vec3 windDir = vec3(0.0, 0.0, 1.0);

vec3 reprojectClouds(vec3 position) {
    vec4 p = gbufferModelViewInverse * vec4(position, 1);
    p.xyz += (cameraPosition + windDir * min(frameTime, 0.1) - previousCameraPosition) * p.w;
    p = gbufferPreviousModelView * p;
    p = gbufferPreviousProjection * p;
    return p.xyz/p.w * 0.5 + 0.5;
}

layout(r11f_g11f_b10f) uniform image2D gpbColor0;
layout(rgba16f) uniform image2D colorimg8;
uniform sampler2D gpbColor0t;

shared float lds[16][16];

void main() {
    
    ivec2 ldsUV = ivec2(gl_LocalInvocationID);
    ivec2 ldsO = ivec2(gl_WorkGroupID * gl_WorkGroupSize) - 4;
    
    lds[ldsUV.x + 0][ldsUV.y + 0] = texelFetch(gpbColor0t, ldsO + ldsUV + ivec2(0,0), 0).y;
    lds[ldsUV.x + 0][ldsUV.y + 8] = texelFetch(gpbColor0t, ldsO + ldsUV + ivec2(0,8), 0).y;
    lds[ldsUV.x + 8][ldsUV.y + 0] = texelFetch(gpbColor0t, ldsO + ldsUV + ivec2(8,0), 0).y;
    lds[ldsUV.x + 8][ldsUV.y + 8] = texelFetch(gpbColor0t, ldsO + ldsUV + ivec2(8,8), 0).y;
    
    barrier();
    
    ivec2 fragCoord = ivec2(gl_GlobalInvocationID);
    
    vec3 centerD = imageLoad(gpbColor0, fragCoord).rgb;
    vec4 clouds = vec4(0,0,1.0,0);
    if (centerD.z != 0.0) {
        float minD = 1000;
        bool cloudFound = false;
        
        for (int x = 0; x<9; x++) {
        for (int y = 0; y<9; y++) {
            float d0 = lds[x][y];
            
            if (d0 > 0.0) {
                cloudFound = true;
                minD = min(minD, d0);
            }
        }}
        
        vec3 view = normalize(projectPoint(vec3((fragCoord + 0.5) * resolutionInv * 2.0 - 1.0, 1.0), gbufferProjectionInverse));
    
        vec3 cloudPos = view * minD;
        vec3 cloudPosPrev = reprojectClouds(cloudPos);
        
        vec2 ft = cloudPosPrev.xy;
        ft.y *= 0.5;
        ft.y += 0.5 * (~frameCounter & 1);
        
        clouds = textureLod(colortex8, ft, 0);
        vec3 cloudsCurr = texelFetch(colortex2, fragCoord, 0).rgb;
        
        
        #ifdef VANILLA_CLOUDS
        const float maxFrames = 4;
        #else 
        const float maxFrames = 12;
        #endif
        
        clouds.a = min(clouds.a + 1.0, maxFrames);
        float blend = 1.0 / clouds.a;
        
        clouds.rgb = mix(clouds.rgb, cloudsCurr, blend);
        
        bool outOfBounds = clamp(cloudPosPrev.xy, vec2(0.0, resolutionInv.y * 0.45), vec2(1.0, 1.0 - resolutionInv.y * 0.45)) != cloudPosPrev.xy;
        
        if (outOfBounds || (!cloudFound && length(cameraVector) > 0.2)) clouds = vec4(cloudsCurr, 0);
        
        centerD.x = minD;
        if (centerD.y > 0.0)
            centerD.x = min(minD + 15.0, centerD.y);
        centerD.x = -view.z * centerD.x;
        
        imageStore(gpbColor0, fragCoord, vec4(centerD, 0));
    }
    
    ivec2 ft = fragCoord;
    ft.y += int(resolution.y) * (frameCounter & 1);
    imageStore(colorimg8, ft, clouds);
}