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
#include "/src/utils/storage.glsl"

mat3 unpackTBN(uvec4 tbnPack, float normalZ) {
    mat3 TBN;
    vec2 t = unpackSnorm2x16(tbnPack.w);
    TBN[0].z = t.x;
    TBN[1].z = t.y;
    TBN[2].z = normalZ;
    TBN[0].xy = unpackSnorm2x16(tbnPack.y);
    TBN[1].xy = unpackSnorm2x16(tbnPack.z);
    TBN[2].xy = unpackSnorm2x16(tbnPack.x);
    
    return TBN;
}

float vertexEmissionThreshold(vec3 albedo) {
    float value = max(max(albedo.r, albedo.g), albedo.b);
    return smoothstep(0.3, 0.7, value) / value;
}

float vertexEmissionThresholdSquare(vec3 albedo) {
    return max(max(albedo.r, albedo.g), albedo.b);
}

vec3 getAlbedo(vec4 textureColor, vec3 vertexColor) {
    return textureColor.rgb * vertexColor;
}

vec3 getEmission(vec3 albedo, vec4 textureSpecular, vec3 vertexEmission) {
    vec3 linearAlbedo = pow(albedo, vec3(2.2));
    return linearAlbedo * max(vertexEmissionThreshold(linearAlbedo) * vertexEmission, fract(textureSpecular.a)) * 8.0 * EMISSION_MULTIPLIER;
}

vec3 getEmission(vec3 albedo, vec4 textureSpecular, vec3 vertexEmission, bool forceTextureColor) {
    vec3 linearAlbedo = pow(albedo, vec3(2.2));
    
    vec3 rpEmission = linearAlbedo * fract(textureSpecular.a);
    vec3 vxEmission = linearAlbedo * vertexEmissionThreshold(linearAlbedo) * vertexEmission;
    vec3 tcEmission = linearAlbedo * vertexEmissionThresholdSquare(linearAlbedo) * 8;
    
    if (forceTextureColor) return max(tcEmission, rpEmission) * (vertexEmission + 1.0) * EMISSION_MULTIPLIER;
    else return max(vxEmission, rpEmission) * 8.0 * EMISSION_MULTIPLIER;
}

vec3 getNormal(vec4 textureNormal, mat3 TBN) {
    vec3 normal;
    normal.xy = textureNormal.xy * 2.0 - 1.0;
    normal.z = sqrt(1.0 - clamp(dot(normal.xy, normal.xy), 0.0, 1.0));
    normal = normalize(TBN*normal);
    return normal;
}

uint getZwidth(float z) {
    float thickness = fwidth(z);
    return uint(min(thickness * (Z_WIDTH_SCALE * 0xFFFFu), float(0xFFFF))) << 16;
}

uint getSSS(vec4 textureSpecular) {
    return uint(textureSpecular.b * 255.0) << 8u;
}

uint getSSS(float textureSpecular) {
    return uint(textureSpecular * 255.0) << 8u;
}

float getAO(float vertexAO) {
    float ao = vertexAO * (2.0 - vertexAO);
    return ao * ao * ao;
}

vec2 getVanillaLight(vec2 lightmapCoordinates, float ao) {
    lightmapCoordinates.x = max(lightmapCoordinates.x, 0.04);
    float lmx = (1.0 - 0.88888 * lightmapCoordinates.x) * 4.0;
    
    return vec2(sqrt((1.0 / (lmx * lmx) - 0.0625) * 0.1), lightmapCoordinates.y * lightmapCoordinates.y) * ao;
}

vec2 getVanillaLight(vec2 lightmapCoordinates) {
    return getVanillaLight(lightmapCoordinates, 1.0);
}

uvec2 packGeometryProperties(vec3 normal, vec3 trueNormal, vec2 roughnessF0) {
    vec2 encodedNormal = octaEncode(normal);
    vec2 encodedTrueNormal = octaEncode(trueNormal) * 0.5 + 0.5;
    uvec2 pack = uvec2(packSnorm2x16(encodedNormal), packUnorm4x8(vec4(encodedTrueNormal, roughnessF0)));
    return pack;
}

uniform int frameCounter;
float bayer4x4(ivec2 coord) {
    coord += ivec2(frameCounter, frameCounter >> 1);
    mat2x2 bayerBase = mat2x2(0.0, 0.75, 0.5, 0.25);
    return bayerBase[coord.x & 1][coord.y & 1] + bayerBase[coord.x>>1 & 1][coord.y>>1 & 1] * 0.25;
}

float packVanillaLight(vec2 lightmapCoordinates) {
    lightmapCoordinates = pow(lightmapCoordinates, vec2(1.0/2.2));
    lightmapCoordinates += (bayer4x4(ivec2(gl_FragCoord)) - 0.5) / 15.0;
    lightmapCoordinates = saturate(lightmapCoordinates);
    lightmapCoordinates = round(lightmapCoordinates * 15);
    return (lightmapCoordinates.y + lightmapCoordinates.x*16) / 255;
}

vec4 gbaa_w(vec2 coords, bvec2 m) {
    vec2 dx = dFdx(coords);
    vec2 dy = dFdy(coords);
    coords = fract(coords);
    
    vec4 w = vec4(1000);
    if (!m.x) {
        vec2 xIntersectionPos = (1.0 - coords) / dx;
        vec2 xIntersectionNeg = (0.0 - coords) / dx;
        vec2 xPos = max(xIntersectionPos, xIntersectionNeg);
        vec2 xNeg = min(xIntersectionNeg, xIntersectionPos);
        w.x = abs(min(xPos.x, xPos.y));
        w.y = abs(max(xNeg.x, xNeg.y));
    }
    if (!m.y) {
        vec2 yIntersectionPos = (1.0 - coords) / dy;
        vec2 yIntersectionNeg = (0.0 - coords) / dy;
        vec2 yPos = max(yIntersectionPos, yIntersectionNeg);
        vec2 yNeg = min(yIntersectionNeg, yIntersectionPos);
        w.z = abs(min(yPos.x, yPos.y));
        w.w = abs(max(yNeg.x, yNeg.y));
    }
    return w;
}

uint gbaa_computeWeights(vec2 quadCoordinates, vec2 atlasCoordinates) {
    
    #if AA == 2
    bool tX = any(greaterThan(abs(dFdx(atlasCoordinates)),vec2(1)));
    bool tY = any(greaterThan(abs(dFdy(atlasCoordinates)),vec2(1)));
    vec4 tW = gbaa_w(atlasCoordinates, bvec2(tX, tY));
    
    
    bool qX = any(greaterThan(abs(dFdx(quadCoordinates)),vec2(1)));
    bool qY = any(greaterThan(abs(dFdy(quadCoordinates)),vec2(1)));
    vec4 qW = gbaa_w(quadCoordinates, bvec2(qX, qY));
    
    vec4 w = tW;
    if (tX || any(lessThan(qW.xy, vec2(1)))) w.xy = qW.xy;
    if (tY || any(lessThan(qW.zw, vec2(1)))) w.zw = qW.zw;
    #else
    bool qX = any(greaterThan(abs(dFdx(quadCoordinates)),vec2(1)));
    bool qY = any(greaterThan(abs(dFdy(quadCoordinates)),vec2(1)));
    vec4 w = gbaa_w(quadCoordinates, bvec2(qX, qY));
    #endif
    
    
    uint l = 0;
    float m = w.x;
    if (w.y < m) { m = w.y; l = 1; }
    if (w.z < m) { m = w.z; l = 2; }
    if (w.w < m) { m = w.w; l = 3; }
    
    if (m > 1.0) m = 0.5;
    
    return (uint(m * 62.0) << 2u) | l;
}

uint GBAA(vec2 quadCoordinates, vec2 atlasCoordinates) {
    return gbaa_computeWeights(quadCoordinates, atlasCoordinates);
}