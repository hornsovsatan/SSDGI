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

#define PERPENDICULAR_EPSILON 0.01

#include "/src/utils/blue_noise.glsl"

vec2 vogelDisc(float sampleIndex, float sampleCount, float phi) {
    const float goldenAngle = 2.39996;

    float r = sqrt(sampleIndex + 0.5) / sqrt(sampleCount);
    float theta = sampleIndex * goldenAngle + phi;

    return vec2(cos(theta), sin(theta)) * r;
}

vec2 vogelDiscSSS(float sampleIndex, float sampleCount, float phi, float penumbra, bool isSSS) {
    const float goldenAngle = 2.39996;
    
    float theta = sampleIndex * goldenAngle + phi;
    float r = sqrt(sampleIndex + 0.5) / sqrt(sampleCount);
    
    
    if (isSSS && sampleIndex/sampleCount > 0.15) 
        r *= r * penumbra + 0.1;
    else 
        r *= penumbra;

    return vec2(cos(theta), sin(theta)) * r;
}


// Declared here, initialized at top of main() in each including shader.
// Uniform/SSBO-based global initializers are illegal GLSL and crash Intel drivers.
vec3 shadowSpaceScale;

vec3 worldToShadowAlignedSpace(vec3 position) {
    vec3 positionAligned = mat4x3(shadowModelView) * vec4(position, 1.0);
    positionAligned.z += shadowProjection[3].z / shadowProjection[2].z;
    return positionAligned;
}

vec3 viewToShadowAlignedSpace(vec3 position) {
    vec3 positionWorld = mat4x3(gbufferModelViewInverse) * vec4(position, 1.0);
    return worldToShadowAlignedSpace(positionWorld);
}


vec3 applyShadowBias(vec3 positionAligned, vec3 normalAligned) {
    vec3 position = positionAligned * shadowSpaceScale;
    float distortion = getDistortionFactorInv(position.xy);
    
    float pixelBias = distortion * distortion * distortion * 3.0 * pow(shadowPixelScale, 1.5);
    
    positionAligned.z += pixelBias * 0.7;
    positionAligned += normalAligned * pixelBias * 0.3;
    positionAligned += normalAligned * 0.02 * length(normalAligned.xy);
    return positionAligned;
}

vec2 drsScale;
vec2 drsOffset;
vec2 drsScaleWindow;
vec2 drsOffsetWindow;

vec3 transformShadowCoord(vec3 positionAligned) {
    vec3 position = positionAligned * shadowSpaceScale;
    position.xy *= 1.0 / getDistortionFactorInv(position.xy);
    position.xy = position.xy * drsScale + drsOffset;
    position = position * 0.5 + 0.5;
    return position;
}


vec2 amalgamaBlocker(vec3 position, vec3 trueNormal, float sss, ivec2 fragCoord) {
    vec3 normalAligned = mat3(shadowModelView) * trueNormal;
    bool facingAway = (normalAligned.z < PERPENDICULAR_EPSILON);
    if (facingAway && sss == 0.0) return vec2(0);
    
    vec3 positionCenter = viewToShadowAlignedSpace(position);
    if (!facingAway)
        positionCenter = applyShadowBias(positionCenter, normalAligned);
    float baseZ = positionCenter.z * shadowSpaceScale.z * 0.25 + 0.75;
    
    float blocker = 0.0;
    float wsum = 0.0;
    for (int i = 0; i<blockerSteps; i++) {
        vec2 offset = blueNoiseCircle(ivec3(fragCoord, i)) * maxPenumbraSize * 1.2;
        float r = length(offset);
        offset *= r;
        
        vec2 sp = positionCenter.xy + offset.xy;
        sp *= shadowSpaceScale.xy;
        sp *= 1.0 / getDistortionFactorInv(sp);
        sp = sp * drsScaleWindow + drsOffsetWindow;
        
        float pz = baseZ + r * r * shadowSpaceScale.z * 0.25 / 0.06;
        
        vec4 shadowDepth = textureGather(shadowtex1, sp, 0);
        vec4 shadowDistance = shadowDepth - pz;
        
        vec4 s = step(shadowDistance, vec4(0));
        blocker += dot(shadowDepth - baseZ, s);
        wsum += dot(s, vec4(1));
    }
    
    return vec2(blocker, wsum);
}







const float maxBlockerWsum = 9 * 4 * blockerSteps;


vec3 amalgamaShadow(vec3 position, vec3 trueNormal, float sss, vec2 blockerData, ivec2 fragCoord) {
    float blocker = blockerData.x;
    float wsum = blockerData.y;
    
    vec3 normalAligned = mat3(shadowModelView) * trueNormal;
    bool facingAway = (normalAligned.z < 0.01);
    if (facingAway && sss == 0.0) return vec3(0);
    vec3 positionCenter = worldToShadowAlignedSpace(position);
    if (!facingAway)
        positionCenter = applyShadowBias(positionCenter, normalAligned);
    float baseZ = positionCenter.z * shadowSpaceScale.z * 0.25 + 0.75;
    
    vec2 centerUV = positionCenter.xy * shadowSpaceScale.xy;
    centerUV /= getDistortionFactorInv(centerUV);

    
    
    vec3 chunkPos = floor(position / 16.0 + fract(cameraPosition / 16));
    const float shadowRadius = shadowDistanceRenderMul * 8.0;
    bool chunkMask = chunkPos == clamp(chunkPos, -shadowRadius, shadowRadius);
    
    vec3 waterAbsorptionCoefficients = vec3(0.09, 0.034, 0.034);
    vec3 waterScatteringCoefficients = vec3(0.01, 0.027, 0.027);
    vec3 waterExtinctionCoefficients = waterAbsorptionCoefficients + waterScatteringCoefficients;
    
    vec2 sp = positionCenter.xy * shadowSpaceScale.xy;
    sp *= 1.0 / getDistortionFactorInv(sp);
    sp = sp * drsScaleWindow + drsOffsetWindow;
    float glassShadowDepth = texelFetch(shadowtex0, ivec2(sp * shadowMapResolution), 0).r;
    vec4 glassColor = texelFetch(shadowcolor0, ivec2(sp * shadowMapResolution), 0);
    float glassShadowDistance = (glassShadowDepth - (baseZ - 0.5)) / (shadowSpaceScale.z * 0.25);
    float glassShadow = step(baseZ - 0.5, glassShadowDepth);
    vec3 tint = glassColor.rgb;
    if (glassColor.a > 0.0) tint *= exp(-max(glassShadowDistance, 0.0) * waterExtinctionCoefficients); 
    tint = mix(tint, vec3(1), glassShadow);
    
    
    
    
    
    //if (wsum == 0.0) return tint;
    blocker /= wsum;
    if (wsum == 0.0) blocker = 0.0;
    blocker /= (shadowSpaceScale.z * 0.25);
    
    float penumbra = 0.005 * blocker;
    penumbra = clamp(clamp(penumbra, minPenumbraSize, maxPenumbraSize), minPenumbraHardening, penumbra * 8.0);
    
    
    float shadow = 0;
    
    float rotation = blueNoiseScalar(ivec3(fragCoord, 0)) * 2.0 * M_PI;
    
    normalAligned.xy /= normalAligned.z;
    normalAligned.xy *= -shadowSpaceScale.z * 0.25;
    
    for (int i = 0; i<penumbraSteps; i++) {
        vec2 offset = vogelDiscSSS(i, penumbraSteps, rotation, penumbra, sss > 0.0);
            
        vec2 sp = positionCenter.xy + offset;
        sp *= shadowSpaceScale.xy;
        sp *= 1.0 / getDistortionFactorInv(sp);
        sp = sp * drsScaleWindow + drsOffsetWindow;
        
        float pz = baseZ + min(0.0, dot(offset, normalAligned.xy));
        
        shadow += textureLod(shadowtex1HW, vec3(sp, pz), 0);
    }
    shadow /= penumbraSteps;
    
    return tint * shadow * shadow;

}