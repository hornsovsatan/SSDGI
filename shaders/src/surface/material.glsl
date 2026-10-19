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
 
#include "/src/utils/storage.glsl"

#define MIN_ROUGHNESS 0.3/255.0

struct material {
    vec3 albedo;
    vec3 normal;
    float roughness;
    float f0;
    vec3 trueNormal;
    vec2 lightmap;
};

vec2 unpackLightmap(float pack) {
    uint u = uint(pack * 255.0);
    return vec2(u >> 4, u & 15u) / 15.0;
}

material assembleMaterial(vec4 albedolmPack, uvec2 geometryPack) {
    vec4 pack = unpackUnorm4x8(geometryPack.y);
    material surface;
    surface.albedo = pow(albedolmPack.rgb, vec3(2.2));
    surface.lightmap = pow(unpackLightmap(albedolmPack.a), vec2(2.2));
    surface.lightmap.x *= surface.lightmap.x;
    surface.normal = normalize(octaDecode(unpackSnorm2x16(geometryPack.x)));
    surface.trueNormal = normalize(octaDecode(pack.xy * 2.0 - 1.0));
    surface.roughness = max(pow(1.0 - pack.z, 2.0), MIN_ROUGHNESS);
    surface.f0 = pack.w;
    
    return surface;
}

material assembleMaterialNoColor(uvec2 geometryPack) {
    vec4 pack = unpackUnorm4x8(geometryPack.y);
    material surface;
    surface.lightmap.x *= surface.lightmap.x;
    surface.normal = normalize(octaDecode(unpackSnorm2x16(geometryPack.x)));
    surface.trueNormal = normalize(octaDecode(pack.xy * 2.0 - 1.0));
    surface.roughness = max(pow(1.0 - pack.z, 2.0), MIN_ROUGHNESS);
    surface.f0 = pack.w;
    
    return surface;
}


material sampleMaterial(sampler2D albedolmTexture, usampler2D geometryTexture, ivec2 P) {
    vec4 albedolmPack   = texelFetch(albedolmTexture,   P, 0).rgba;
    uvec2 geometryPack  = texelFetch(geometryTexture,   P, 0).rg;
    return assembleMaterial(albedolmPack, geometryPack);
}

material sampleMaterialNoColor(usampler2D geometryTexture, ivec2 P) {
    uvec2 geometryPack  = texelFetch(geometryTexture, P, 0).rg;
    return assembleMaterialNoColor(geometryPack);
}

uvec3 sampleMaterialPacked(sampler2D albedolmTexture, usampler2D geometryTexture, ivec2 P) {
    vec4 albedolmPack   = texelFetch(albedolmTexture,   P, 0).rgba;
    uvec2 geometryPack  = texelFetch(geometryTexture,   P, 0).rg;
    return uvec3(packUnorm4x8(albedolmPack), geometryPack);
}


float sampleMaterialSSS(usampler2D sssTexture, ivec2 P) {
    uint sssPack  = (texelFetch(sssTexture, P, 0).r >> 8u) & 0xFFu;
    return saturate((sssPack - 65.0) / 190.0);
}



vec3 getAlbedo(uvec3 packedMaterial) {
    return pow(unpackUnorm4x8(packedMaterial.x).rgb, vec3(2.2));
}

vec3 getNormal(uvec3 packedMaterial) {
    return normalize(octaDecode(unpackSnorm2x16(packedMaterial.y)));
}

float getRoughness(uvec3 packedMaterial) {
    return max(pow(1.0 - unpackUnorm4x8(packedMaterial.z).z, 2.0), MIN_ROUGHNESS);
}

float getF0(uvec3 packedMaterial) {
    return unpackUnorm4x8(packedMaterial.z).w;
}

vec3 getTrueNormal(uvec3 packedMaterial) {
    return normalize(octaDecode(unpackUnorm4x8(packedMaterial.z).xy * 2.0 - 1.0));
}

vec2 getLightmap(uvec3 packedMaterial) {
    vec2 lightmap = pow(unpackLightmap(unpackUnorm4x8(packedMaterial.x).a), vec2(2.2));
    lightmap.x *= lightmap.x;
    return lightmap;
}