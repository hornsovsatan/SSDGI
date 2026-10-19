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
#include "/src/utils/gamma_correction.glsl"
#include "/src/utils/storage.glsl"

float vertexEmissionThreshold(vec3 albedo) {
    float value = max(max(albedo.r, albedo.g), albedo.b);
    return smoothstep(0.4, 0.7, value) / value;
}


vec3 getAlbedo(vec4 textureColor, vec3 vertexColor) {
    return textureColor.rgb * vertexColor;
}

vec3 getEmission(vec3 albedo, vec4 textureSpecular, vec3 vertexEmission) {
    vec3 linearAlbedo = removeGamma(albedo);
    return linearAlbedo * max(vertexEmissionThreshold(linearAlbedo) * vertexEmission, fract(textureSpecular.a));
}

vec3 getNormal(vec4 textureNormal, mat3 TBN) {
    vec3 normal;
    normal.xy = textureNormal.xy * 2.0 - 1.0;
    normal.z = sqrt(1.0 - clamp(dot(normal.xy, normal.xy), 0.0, 1.0));
    normal = normalize(TBN*normal);
    return normal;
}

float getZwidth(float z) {
    float thickness = fwidth(z);
    return thickness;
}


uvec2 packGeometryProperties(vec3 normal, vec3 trueNormal, vec2 roughnessF0) {
    vec2 encodedNormal = octaEncode(normal);
    vec2 encodedTrueNormal = octaEncode(trueNormal) * 0.5 + 0.5;
    uvec2 pack = uvec2(packSnorm2x16(encodedNormal), packUnorm4x8(vec4(encodedTrueNormal, roughnessF0)));
    return pack;
}

float bayer4x4(ivec2 coord) {
    mat2x2 bayerBase = mat2x2(0.0, 0.75, 0.5, 0.25);
    return bayerBase[coord.x & 1][coord.y & 1] + bayerBase[coord.x>>1 & 1][coord.y>>1 & 1] * 0.25;
}

float packLightmap(vec2 lightmapCoordinates) {
    lightmapCoordinates = lightmapCoordinates;
    lightmapCoordinates += (bayer4x4(ivec2(gl_FragCoord)) - 0.5) / 15.0;
    lightmapCoordinates = clamp(lightmapCoordinates, 0.0, 1.0);
    lightmapCoordinates = round(lightmapCoordinates * 15);
    return (lightmapCoordinates.y + lightmapCoordinates.x*16) / 255;
}

vec4 gbaa_computeWeights(vec2 quadCoordinates) {
    vec2 dx = dFdx(quadCoordinates);
    vec2 dy = dFdy(quadCoordinates);
    
    vec2 xIntersectionPos = ( 1 - quadCoordinates) / dx;
    vec2 xIntersectionNeg = (-1 - quadCoordinates) / dx;
    
    vec2 yIntersectionPos = ( 1 - quadCoordinates) / dy;
    vec2 yIntersectionNeg = (-1 - quadCoordinates) / dy;
    
    bvec2 flipX = lessThan(xIntersectionPos,xIntersectionNeg);
    bvec2 flipY = lessThan(yIntersectionPos,yIntersectionNeg);
    
    vec2 xPos = mix(xIntersectionPos, xIntersectionNeg, flipX);
    vec2 xNeg = mix(xIntersectionNeg, xIntersectionPos, flipX);
    vec2 yPos = mix(yIntersectionPos, yIntersectionNeg, flipY);
    vec2 yNeg = mix(yIntersectionNeg, yIntersectionPos, flipY);
    
    float tXPos =  min(xPos.x, xPos.y);
    float tXNeg = -max(xNeg.x, xNeg.y);
    float tYPos =  min(yPos.x, yPos.y);
    float tYNeg = -max(yNeg.x, yNeg.y);
    
    if (tXPos>1) tXPos = 0.5;
    if (tXNeg>1) tXNeg = 0.5;
    if (tYPos>1) tYPos = 0.5;
    if (tYNeg>1) tYNeg = 0.5;
    
    vec4 weights = vec4(tXPos, tXNeg, tYPos, tYNeg);
    
    if (any(greaterThan(abs(dFdx(quadCoordinates)),vec2(2)))) weights.xy = vec2(0.5);
    if (any(greaterThan(abs(dFdy(quadCoordinates)),vec2(2)))) weights.zw = vec2(0.5);
        
    return weights;
}

uvec2 GBAA(vec2 quadCoordinates) {
    vec4 gbaaWeights = gbaa_computeWeights(quadCoordinates);
    uvec4 edge = min(uvec4(round(gbaaWeights * 14.0)), 14);
    uvec2 packedEdge = edge.xz | (edge.yw<<4);
    return packedEdge;
}