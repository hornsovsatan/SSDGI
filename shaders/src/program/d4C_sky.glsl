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

#include "/src/lighting/atmosphere.glsl"

layout (r11f_g11f_b10f) uniform image2D skyimg;



#if DIMENSION == DIM_OVERWORLD
const ivec3 workGroups = ivec3(16, 16, 1);
layout (local_size_x = 8, local_size_y = 8) in;

vec3 uvToDir(vec2 uv) {
    float azimuth = (uv.x - 0.5) * 2.0 * M_PI;
    float alt = uv.y * 2.0 - 1.0;
    alt *= abs(alt) * M_PI * 0.5;
    return vec3(sin(azimuth) * cos(alt), sin(alt), cos(azimuth) * cos(alt));
}

uniform sampler2D skyLUTtex;

void main() {
    atmosphereDriver();
    
    ivec2 threadCoord = ivec2(gl_GlobalInvocationID);
    threadCoord.y <<= 1;
    threadCoord.y |= (threadCoord.x + frameCounter) & 1;
    
    
    vec3 sun = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 camera = vec3(0, earthRadius + cameraPosition.y - seaLevel, 0);
    
    vec2 uv = vec2(threadCoord + 0.5) / vec2(256, 255);
    
    vec3 D = uvToDir(uv);
    vec2 sunX = normalize(sun.xz);
    D.xz = D.z * sunX + vec2(-1, 1) * sunX.yx * D.x;
    
    vec2 hitEarth = atmo_raySphereIntersection(camera, D, earthRadius);
    vec2 hitAtmosphere = atmo_raySphereIntersection(camera, D, atmosphereRadius);
    
    vec2 hit = hitAtmosphere;
    hit = max(hit, 0.0);
    if (hitEarth.y > 0.0) hit.y = max(hitEarth.x, 0.0);
    
    vec2 hitC = min(hit, 4000.0);
    vec2 hitF = max(hit, 4000.0);
    
    
    vec3 transmittanceC;
    vec3 inscatteringC = atmo_getSegmentInscatteringEnvmap(camera + D * hitC.x, D, hitC.y - hitC.x, sun, skyLUTtex, transmittanceC);
    
    vec3 transmittanceF;
    vec3 inscatteringF = atmo_getSegmentInscatteringEnvmap(camera + D * hitF.x, D, hitF.y - hitF.x, sun, skyLUTtex, transmittanceF);
    
    vec3 transmittance = transmittanceC * transmittanceF;
    vec3 inscattering = inscatteringC + inscatteringF * transmittanceC;
    
    if (hitEarth.y > 0.0) transmittance = vec3(0.0);
    
    imageStore(skyimg, threadCoord, vec4(inscattering, 0));
    imageStore(skyimg, threadCoord + ivec2(0, 256), vec4(transmittance, 0));
}
#endif


#if DIMENSION == DIM_END
const ivec3 workGroups = ivec3(16, 32, 1);
layout (local_size_x = 8, local_size_y = 8) in;

vec3 uvToDir(vec2 uv) {
    float azimuth = (uv.x - 0.5) * 2.0 * M_PI;
    float alt = uv.y * 2.0 - 1.0;
    alt *= M_PI * 0.5;
    return vec3(sin(azimuth) * cos(alt), sin(alt), cos(azimuth) * cos(alt));
}

void main() {
    ivec2 threadCoord = ivec2(gl_GlobalInvocationID);
    vec2 uv = vec2(threadCoord + 0.5) / vec2(127, 255);
    vec3 D = uvToDir(uv);
    
    vec3 transmittance;
    vec3 inscattering = atmo_getSegmentInscatteringEND(cameraPosition, D, 1000.0, 256, transmittance);
    
    imageStore(skyimg, threadCoord, vec4(inscattering, 0.0));
    imageStore(skyimg, threadCoord + ivec2(0, 256), vec4(0.0));
}
#endif

#if DIMENSION == DIM_NETHER
const ivec3 workGroups = ivec3(16, 32, 1);
layout (local_size_x = 8, local_size_y = 8) in;

vec3 uvToDir(vec2 uv) {
    float azimuth = (uv.x - 0.5) * 2.0 * M_PI;
    float alt = uv.y * 2.0 - 1.0;
    alt *= M_PI * 0.5;
    return vec3(sin(azimuth) * cos(alt), sin(alt), cos(azimuth) * cos(alt));
}

void main() {
    ivec2 threadCoord = ivec2(gl_GlobalInvocationID);
    vec2 uv = vec2(threadCoord + 0.5) / vec2(127, 255);
    vec3 D = uvToDir(uv);
    
    vec3 transmittance;
    vec3 inscattering = atmo_getSegmentInscatteringNETHER(cameraPosition, D, 1000.0, 256, transmittance);
    
    imageStore(skyimg, threadCoord, vec4(inscattering, 0.0));
    imageStore(skyimg, threadCoord + ivec2(0, 256), vec4(0.0));
}
#endif