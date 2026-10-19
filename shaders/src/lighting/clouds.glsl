/*
 * All Rights Reserved
 * 
 * Copyright (c) 2025 jbritain
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

#include "/src/utils/blue_noise.glsl"

uniform sampler3D cloudshapetex;
uniform sampler3D clouddetailtex;
uniform sampler2D cloudcoveragetex;
uniform sampler2D vanillacloudtex;

// #define VANILLA_CLOUDS
// #define BLOCKY_CLOUDS
#define CLOUD_SHADOWS
// #define frameTimeCounter 0.0 

#ifdef VANILLA_CLOUDS
    #define CLOUDS_BASE_ALTITUDE 192.0
    #define CLOUDS_TOP_ALTITUDE 196.0
    #define CLOUD_PRIMARY_SAMPLES 4
    #define CLOUD_SECONDARY_SAMPLES 1
    #define CLOUDS_DENSITY 2.0
    #define CLOUDS_MULTIPLE_SCATTERING 500.0
#else
    #define CLOUDS_BASE_ALTITUDE 220.0
    #define CLOUDS_TOP_ALTITUDE 310.0
    #define CLOUD_PRIMARY_SAMPLES 8
    #define CLOUD_SECONDARY_SAMPLES 3
    #define CLOUDS_DENSITY 0.17
    #define CLOUDS_MULTIPLE_SCATTERING 500.0
#endif

const float cloudScattering = 2.0;
const float cloudAbsorption = 0.44;
const float cloudExtinction = cloudScattering + cloudAbsorption;

const vec3 windDir = vec3(0.0, 0.0, 1.0);

float linearstep(float edge0, float edge1, float x) {
    return clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
}

float remap(float val, float oMin, float oMax, float nMin, float nMax) {
    return mix(nMin, nMax, linearstep(oMin, oMax, val));
}

const float isotropicPhase = 1.0 / (4.0 * M_PI);

float henyeyGreensteinPhase(float cos_theta, float g) {
    return (1.0 - g * g) /
    (4.0 * M_PI * pow(1.0 + g * g - 2.0 * g * cos_theta, 3.0 / 2.0));
}

float drainePhase(float cos_theta, float g, float a) {
    return (1 - g * g) *
    (1 + a * cos_theta * cos_theta) /
    (4.0 *
      (1 + a * (1 + 2 * g * g) / 3.0) *
      M_PI *
      pow(1 + g * g - 2 * g * cos_theta, 1.5));
}

float hgDrainePhase(float cos_theta, float d) {
    float g_hg = exp(-0.0990567 / (d - 1.67154));
    float g_d = exp(-2.20679 / (d + 3.91029) - 0.428934);
    float a = exp(3.62489 - 8.29288 / (d + 5.52825));
    float w = exp(-0.599085 / (d - 0.641583) - 0.665888);

    return mix(
        henyeyGreensteinPhase(cos_theta, g_hg),
        drainePhase(cos_theta, g_d, a),
        w
    );
}

//Returns closest and farthest intersection distances in x and y respectively
vec2 intersectBoundingVolume(vec3 cameraPosition, vec3 direction, vec2 height) {
    if (direction.y < 0.0) height = height.yx;
    vec2 planeDistance = height - cameraPosition.y;
    return planeDistance / direction.y;
}

float intersectPlane(vec3 cameraPosition, vec3 direction, float height) {
    float planeDistance = height - cameraPosition.y;
    return planeDistance / direction.y;
}


float getCloudDensity(vec3 rayPos, bool highQuality){
    #ifdef VANILLA_CLOUDS
        vec2 samplePos = (rayPos.xz + vec2(frameTimeCounter, 0.0)) * 2.0;
        ivec2 p = ivec2(floor(mod((samplePos) / 24, 256)));

        return texelFetch(vanillacloudtex, p, 0).r * CLOUDS_DENSITY;
    #else
        vec3 wind = windDir * frameTimeCounter;

        rayPos += wind;
        
        #ifdef BLOCKY_CLOUDS
            uint seed = hash33(floor(rayPos / 8));
            vec3 s;
            s.x = ((seed &  3u) == 0u) ? 4.0 : 8.0;
            s.y = ((seed & 12u) == 0u) ? 4.0 : 8.0;
            s.z = ((seed & 48u) == 0u) ? 4.0 : 8.0;
            
            rayPos = floor(rayPos / s) * s;
        #endif

        float heightInPlane = linearstep(CLOUDS_BASE_ALTITUDE - 20, CLOUDS_TOP_ALTITUDE + 90, rayPos.y);
        rayPos += windDir * heightInPlane * 20.0;

        // Based loosely upon "Real Time Volumetric Cloudscapes" by Andrew Schneider in GPU Pro 7
        // Coverage texture generated with 'Strepitus' by luna5ama (https://github.com/luna5ama/strepitus)
        // Shape and detail textures generated with jaekmichie97's noise generator (https://github.com/jcm2606/volume-noise-generator)
        float coverage = smoothstep(0.7, 1.0, textureLod(cloudcoveragetex, fract(rayPos.xz / 7500.0), 0).r);

        coverage += rainStrength * 0.9;
        coverage = min(coverage, 1.2);

        coverage *= heightInPlane * 0.3 + 0.7;
        
        // coverage = sqrt(coverage);
        
        if (coverage == 0.0) return 0.0;

        vec4 lowFrequencyNoise = textureLod(cloudshapetex, fract(rayPos.xyz / 300.0), 0);
        float lowFrequencyFBM = lowFrequencyNoise.g * 0.625 + lowFrequencyNoise.b * 0.25 + lowFrequencyNoise.a * 0.125;
        float density = remap(lowFrequencyNoise.r, lowFrequencyFBM * 0.7, 1.0, 0.0, 1.0);
        density = sqrt(density);
        
        float heightFactor = min(smoothstep(0.0, 0.2, heightInPlane), 1.0 - linearstep(0.2, 1.0, heightInPlane));
        density *= heightFactor;

        density = remap(density, 1.0 - coverage, 1.0, 0.0, 1.0);
        // density *= coverage;

        density = pow(density, 1.5);

        if(highQuality){
            vec3 highFrequencyNoise = textureLod(clouddetailtex, fract(rayPos.xyz / 50.0 + vec3(wind.x * 0.01, 0.0, wind.y * 0.01)), 0).rgb;
            float highFrequencyFBM = highFrequencyNoise.r * 0.625 + highFrequencyNoise.g * 0.25 + highFrequencyNoise.b * 0.125;
            highFrequencyFBM = mix(highFrequencyFBM, 1.0 - highFrequencyFBM, saturate(heightInPlane * 10.0));

            density = remap(density, highFrequencyFBM * 0.5, 1.0, 0.0, 1.0);
        } else {
            density = remap(density, 0.25, 1.0, 0.0, 1.0); // the remap operation from the high quality noise affects the overall density - this emulates that
        }

        density *= smoothstep(0.0, 0.5, density);
        


        return density * CLOUDS_DENSITY * (1.0 + rainStrength * 0.5);
    #endif
}


// TODO: move this somewhere more sensible
vec3 unmapSphere(vec2 uv) {
    float phi = (uv.x - 0.5) * 2.0 * 3.14;
    float theta = (uv.y - 0.5) * 3.14;
    
    float y = sin(theta);
    float cosPhi = cos(phi);
    float sinPhi = sin(phi);
    float cosTheta = cos(theta);
    
    return vec3(
        cosTheta * cosPhi,
        y,
        cosTheta * sinPhi
    );
}

float getTransmittanceToSun(vec3 start, vec3 dir, float jitter){
    float rayLength = intersectBoundingVolume(start, dir, vec2(CLOUDS_BASE_ALTITUDE, CLOUDS_TOP_ALTITUDE)).y;
    if (rayLength < 0.0) return 1.0;
    rayLength = min(rayLength, 100.0);

    float density = 0.0;

    vec3 previousSamplePos = start;
    for (int i = 0; i < CLOUD_SECONDARY_SAMPLES; i++) {
        float progress = (float(i) + jitter) / float(CLOUD_SECONDARY_SAMPLES);
        vec3 samplePos = start + dir * rayLength * exp(5.0 * (progress - 1.0));

        density +=
        getCloudDensity(samplePos, false) *
        distance(previousSamplePos, samplePos);

        previousSamplePos = samplePos;
    }

    return exp(-density * cloudExtinction);
}

vec2 getRayBoundaries(vec3 pos, vec3 direction, float maxDistance) {
    vec2 hit = intersectBoundingVolume(pos, direction, vec2(CLOUDS_BASE_ALTITUDE, CLOUDS_TOP_ALTITUDE));
    hit = clamp(hit, 5.0, maxDistance);
    hit.y = min(hit.y, hit.x + 1000.0);
    return hit;
}

vec2 getRayBoundaries(vec3 direction, float maxDistance) {
    return getRayBoundaries(cameraPosition, direction, maxDistance);
}

vec3 getCloudSegment(vec3 dir, vec2 segmentEnds, vec3 sunDir, out float closestHit, vec2 jitter){
    
    vec3 jitteredSunDir = normalize(sunDir + unmapSphere(jitter) * 0.1);
    

    float transmittance = 1.0;
    vec2 scattering = vec2(0.0);
    closestHit = 0.0;

    float phase = hgDrainePhase(dot(dir, sunDir), 11);

    float stepLength = (segmentEnds.y - segmentEnds.x) / CLOUD_PRIMARY_SAMPLES;

    for(int i = 0; i < CLOUD_PRIMARY_SAMPLES; i++){
        float t = mix(segmentEnds.x, segmentEnds.y, (i + jitter.x) / float(CLOUD_PRIMARY_SAMPLES));
        vec3 rayPos = cameraPosition + dir * t;
        
        float density = getCloudDensity(rayPos, true);
        if(density < 0.002){
            continue;
        }

        float sampleTransmittance = exp(-density * stepLength * cloudExtinction);

        if(closestHit == 0.0) closestHit = t;

        // single scattering
        float transmittanceToSun = getTransmittanceToSun(rayPos, jitteredSunDir, jitter.y);
        float radianceSun = transmittanceToSun * phase;

        // multiple scattering approximation by ohmygggod (窝的舔)
        // https://zhuanlan.zhihu.com/p/457997155
        // "discovered" by Luna5ama
        float fMS = (1.0 - exp(-CLOUDS_MULTIPLE_SCATTERING * density * cloudExtinction * stepLength)) * cloudScattering / cloudExtinction;
        fMS = mix(fMS, fMS * 0.99, smoothstep(0.99, 1.0, fMS)); // this part by luna
        radianceSun += transmittanceToSun * isotropicPhase * fMS / (1.0 - fMS);
       
        // ambient scattering
        float radianceSky = 1.0;
       
        scattering += transmittance * (vec2(radianceSun, radianceSky) * (1.0 - saturate(sampleTransmittance)) * cloudScattering / cloudExtinction);
        transmittance *= sampleTransmittance;
        
        if (transmittance < 0.2) break;
    }

    // apply aerial perspective to clouds
    if(closestHit != 0.0){
        vec3 camera = vec3(0, earthRadius + cameraPosition.y - seaLevel, 0);
        // this works on the assumption that any significant aerial perspective
        // will be on a cloud with sky behind it
        // therefore instead of rendering the atmosphere on top of it
        // we can just fade it back into the sky
        vec3 atmoTransmittance = atmo_getSegmentTransmittance(camera, dir, closestHit);
        
        scattering *= dot(atmoTransmittance, vec3(0.33));
        transmittance = mix(1.0, transmittance, dot(atmoTransmittance, vec3(0.33)));
    }
    
    //vec3 trueScattering = scattering.x * sunlightColor + scattering.y * averageSkyInscattering;
    
    return vec3(scattering, transmittance);
}

float getCloudDensityS(vec3 rayPos){
    #ifdef VANILLA_CLOUDS
        vec2 samplePos = (rayPos.xz + vec2(frameTimeCounter, 0.0)) * 2.0;
        ivec2 p = ivec2(floor(mod((samplePos) / 24, 256)));

        return texelFetch(vanillacloudtex, p, 0).r;
    #else
        rayPos += windDir * frameTimeCounter;
        float coverage = smoothstep(0.5, 1.0, textureLod(cloudcoveragetex, fract(rayPos.xz / 7500.0), 0).r);

        coverage += rainStrength * 0.9;
        coverage = min(coverage, 1.2);
        return coverage * 0.17 - 0.145;
 
    #endif
}

float getCloudShadow(vec3 pos, vec3 sunDir){
    float shadowOpacity = mix(0.7, 0.3, rainStrength);
    
    pos += cameraPosition;
    float planeHeight = mix(CLOUDS_BASE_ALTITUDE, CLOUDS_TOP_ALTITUDE, 0.2);
    float t = intersectPlane(pos, sunDir, planeHeight);
    if (t < 0) return 1.0;
    vec3 samplePos = pos + sunDir * t;
    return 1.0 - smoothstep(0.0, 0.03, getCloudDensityS(samplePos)) * shadowOpacity;
}