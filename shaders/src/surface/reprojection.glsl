/*
 * All Rights Reserved
 * 
 * Copyright (c) 2024-2025 lipesto
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

#include "/src/utils/storage.glsl"

vec4 getBilinearWeights(vec2 coord) {
    vec2 fac = fract(coord - 0.5);
    vec4 weights;
    weights.xz = 1.0 - fac.yy;
    weights.yw = fac.yy;
    weights.xy *= 1.0 - fac.x;
    weights.zw *= fac.x;
    return weights.ywzx;
}

bvec4 outOfBoundsQuad(ivec2 origin, ivec2 resolution) {
    return bvec4(
    any(lessThan(origin + ivec2(0, 1), resolution)) ||  any(greaterThanEqual(origin + ivec2(0, 1), ivec2(0))),
    any(lessThan(origin + ivec2(1, 1), resolution)) ||  any(greaterThanEqual(origin + ivec2(1, 1), ivec2(0))),
    any(lessThan(origin + ivec2(1, 0), resolution)) ||  any(greaterThanEqual(origin + ivec2(1, 0), ivec2(0))),
    any(lessThan(origin + ivec2(0, 0), resolution)) ||  any(greaterThanEqual(origin + ivec2(0, 0), ivec2(0))));
}


mat4 gatherColor(sampler2D channel, ivec2 origin, bvec4 mask) {
    mat4 data;
    data[0] = mask[0] ? texelFetchOffset(channel, origin, 0, ivec2(0, 1)) : vec4(0);
    data[1] = mask[1] ? texelFetchOffset(channel, origin, 0, ivec2(1, 1)) : vec4(0);
    data[2] = mask[2] ? texelFetchOffset(channel, origin, 0, ivec2(1, 0)) : vec4(0);
    data[3] = mask[3] ? texelFetchOffset(channel, origin, 0, ivec2(0, 0)) : vec4(0);
    return data;
}



struct geometryData {
    mat4x3 normal;
    vec4 viewZ;
    vec4 roughness;
};

geometryData gatherGeometryDataR(usampler2D geometryChannel, ivec2 origin, bvec4 mask) {
    geometryData data = geometryData(mat4x3(0), vec4(0), vec4(0));
    if (mask[0]) unpackGeometryData(texelFetchOffset(geometryChannel, origin, 0, ivec2(0, 1)).rg, data.normal[0], data.viewZ[0], data.roughness[0]);
    if (mask[1]) unpackGeometryData(texelFetchOffset(geometryChannel, origin, 0, ivec2(1, 1)).rg, data.normal[1], data.viewZ[1], data.roughness[1]);
    if (mask[2]) unpackGeometryData(texelFetchOffset(geometryChannel, origin, 0, ivec2(1, 0)).rg, data.normal[2], data.viewZ[2], data.roughness[2]);
    if (mask[3]) unpackGeometryData(texelFetchOffset(geometryChannel, origin, 0, ivec2(0, 0)).rg, data.normal[3], data.viewZ[3], data.roughness[3]);
    return data;
}

//AMD compatibility fix
bvec4 bAnd(bvec4 A, bvec4 B) {
    bvec4 C;
    C.x = A.x && B.x;
    C.y = A.y && B.y;
    C.z = A.z && B.z;
    C.w = A.w && B.w;
    return C;
}

mat3x4 reproject(vec3 position, material surface, sampler2D diffuseChannel, sampler2D specularChannel, sampler2D momentsChannel, usampler2D geometryChannel, bool isHand) {
    vec3 previousNormal = mat3(gbufferPreviousModelView) * (mat3(gbufferModelViewInverse) * surface.normal);
    
    //Reproject fragment
    vec3 previousViewPosition;
    if (isHand) {
        previousViewPosition = position + (gbufferPreviousModelView[3].xyz - gbufferModelView[3].xyz) * 0.3;
    } else {
        vec3 worldPosition = mat4x3(gbufferModelViewInverse) * vec4(position, 1.0);
        vec3 previousWorldPosition = worldPosition - cameraVector;
        previousViewPosition = mat4x3(gbufferPreviousModelView) * vec4(previousWorldPosition, 1.0);
    }
    vec3 previousScreenPosition = projectPoint(previousViewPosition, isHand ? gbufferProjection : gbufferPreviousProjection) * 0.5 + 0.5;
    
    if (saturate(previousScreenPosition.z) != previousScreenPosition.z) return mat3x4(0);
    
    previousScreenPosition.xy *= resolution;
    ivec2 sampleOrigin = ivec2(previousScreenPosition.xy - 0.5);
    
    //Generate mask
    bvec4 mask = outOfBoundsQuad(sampleOrigin, ivec2(resolution));
    vec4 weightsB = getBilinearWeights(previousScreenPosition.xy);
    mask = bAnd(mask, greaterThan(weightsB, vec4(0.001)));
    
    //Gather data
    geometryData geometry = gatherGeometryDataR(geometryChannel, sampleOrigin, mask);
    mat4 quadDiffuse =  gatherColor(diffuseChannel, sampleOrigin, mask);
    mat4 quadSpecular = gatherColor(specularChannel, sampleOrigin, mask);
    #if DENOISER == 2
    mat4 quadMoments = gatherColor(momentsChannel, sampleOrigin, mask);
    #endif
    
    //Compute geometry weights
    mat4x3 normals = geometry.normal;
    vec4 viewZprev = geometry.viewZ;
    float plane = dot(previousViewPosition, surface.trueNormal);
    vec4 planeDistance = abs((viewZprev / previousViewPosition.z - 1.0) * plane);
    
    vec4 weightsZ = 1.0 - step(0.005, planeDistance / length(previousViewPosition));
    vec4 weightsN = pow(max(previousNormal * normals, 0.0), vec4(127.0));
    vec4 weightsR = step(abs(surface.roughness - geometry.roughness), vec4(0.05));
    
    float wsumN = dot(weightsN, vec4(0.25));
    if (wsumN != 0.0) weightsN /= wsumN;
    
    vec4 weightsD = weightsB * weightsZ * weightsN;
    vec4 weightsS = weightsB * weightsZ * weightsN * weightsR;
    float wsumD = dot(weightsD, vec4(1.0));
    float wsumS = dot(weightsS, vec4(1.0));
    
    
    vec4 diffuse = quadDiffuse * weightsD;
    vec4 specular = quadSpecular * weightsS;
    
    
    vec4 moments;
    #if DENOISER == 2
    moments.xy =    quadMoments[0].xy * weightsD.x + 
                    quadMoments[1].xy * weightsD.y + 
                    quadMoments[2].xy * weightsD.z + 
                    quadMoments[3].xy * weightsD.w;
                    
    moments.zw =    quadMoments[0].zw * weightsS.x + 
                    quadMoments[1].zw * weightsS.y + 
                    quadMoments[2].zw * weightsS.z + 
                    quadMoments[3].zw * weightsS.w;
    moments.xy /= wsumD + 1e-10;
    moments.zw /= wsumS + 1e-10;
    #endif
    
    
    diffuse.rgb /= wsumD + 1e-10;
    specular.rgb /= wsumS + 1e-10;
    diffuse.a = round(diffuse.a);
    specular.a = round(specular.a);
    
    return mat3x4(diffuse, specular, moments);
    
}
