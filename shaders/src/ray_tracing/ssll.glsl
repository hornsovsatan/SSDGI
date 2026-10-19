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

const float targetCoverage = 1.0 / 32.0;
const int clusterN = 32;

uint totalBitmasks;
uint totalTiles;

float trapezoidArea(vec3 position, float width, mat4 projectionInverse) {
    vec4 F = projectionInverse * vec4(position.xy, position.z + width, 1.0);
    vec4 N = projectionInverse * vec4(position.xy, position.z - width, 1.0);
    
    float pixelEdgeSize = projectionInverse[0].x * resolutionInv.x + projectionInverse[1].y * resolutionInv.y;
    float pixelEdgeSizeF = pixelEdgeSize / F.w;
    float pixelEdgeSizeN = pixelEdgeSize / N.w;
        
    vec3 crossDistance = N.xyz/N.w - F.xyz/F.w;
    float pixelEdgeDistance = (pixelEdgeSizeF + pixelEdgeSizeN) * 0.5;
    
    float h0 = length(vec2(pixelEdgeDistance + crossDistance.x, crossDistance.z));
    float h1 = length(vec2(pixelEdgeDistance - crossDistance.x, crossDistance.z));
    float h2 = length(vec2(pixelEdgeDistance + crossDistance.y, crossDistance.z));
    float h3 = length(vec2(pixelEdgeDistance - crossDistance.y, crossDistance.z));
    
    float area = (pixelEdgeSizeF + pixelEdgeSizeN) * (h0 + h1 + h2 + h3) / 8.0;
    return area;
}

const int b = 16; //Accounted for ^1/5

uint getQ(float w) {
    const float maxFloat = exp2(32-b) * 2047.0/2048.0;
    const float minFloat = exp2(-b);
    return uint(clamp(w, minFloat, maxFloat) * exp2(b) + 0.5) * uint(w > 0.0);
}

float getQweight(uint Q) {
    return Q * exp2(-b);
}

ivec2 idToCoord(uint id) {
    return ivec2(id % int(resolution), id / int(resolution));
}

uvec2 unpackUvec2(uint pack) {
    return uvec2(pack & 0xFFFFu, pack >> 16);
}

#ifdef SSLL_SAMPLING

float geometryWeight(vec3 shadingPosition, vec3 shadingNormal, vec3 lightNormal, ivec2 lightUV, float lightDepth) {
    vec3 lightPosition = projectPoint(vec3((lightUV + 0.5) * resolutionInv, lightDepth) * 2.0 - 1.0, gbufferProjectionInverse);
    float r = distance(shadingPosition, lightPosition);
    vec3 lightDir = (lightPosition - shadingPosition) / r;
    return max(0.0, dot(lightDir, shadingNormal)) * max(0.0, dot(lightNormal, -lightDir)) / (r*r);
}

vec4 unpackUnorm3x6Ufloat14x1(uint p) {
    vec3 v = vec3((uvec3(p) >> uvec3(14, 20, 26))&0x3Fu) / 63.0;
    float f = unpackHalf2x16(p & 0x3FFF).x;
    return vec4(v, f);
}

struct ssll_clusterData{
    ivec2 uv;
    float LOS;
    float depth;
    vec3 normal;
    vec3 center;
    float radius;
    vec3 avgNormal;
    float normalLength;
    float P;
};

ssll_clusterData unpackCluster(uvec2 P01, uvec2 P23, uvec2 P45) {
    ssll_clusterData cluster;
    cluster.uv = ivec2(unpackUvec2(P01.x));
    vec2 p = unpackHalf2x16(P01.y);
    cluster.LOS = p.y;
    cluster.depth = 1.0 - p.x;
    vec4 t0 = unpackUnorm3x6Ufloat14x1(P45.y);
    vec2 t1 = unpackHalf2x16(P23.y);
    vec2 t2 = unpackHalf2x16(P45.x);
    vec4 t3 = unpackSnorm4x8(P45.y);
    cluster.normal = unpackSnorm4x8(P23.x).xyz;
    cluster.center = vec3(t1,t2.x);
    cluster.radius = t2.y;
    cluster.avgNormal = t0.xyz * 2.0 - 1.0;
    cluster.normalLength = float(P23.x >> 24) / 255.0;
    cluster.P = t0.w;
    
    return cluster;
}

struct ssll_LightSource {
    ivec2 uv;
    float LOS;
    float weight;
    float depth;
    vec3 normal;
};

ssll_LightSource ssll_GetLight(vec3 position, vec3 normal, inout uint seed) {
    uint totalLights = ssllCounters[4];
    
    //WRS RENDERING
    ssll_clusterData rLight;
    float lW = 0;
    float lWW = 0;
    float wsum = 0;
    float wwsum = 0;
    
    int N = 4;
    
    for (int i = 0; i<N; i += 1) {
        
        ivec2 rndOffset = ivec2(rnd(seed) * (ssllRadius.x * 2 + 1), rnd(seed) * (ssllRadius.y * 2 + 1));
        ivec2 baseUV = ivec2(gl_LocalInvocationID) / 4;
        uvec2 LP0 = lds[baseUV.x + rndOffset.x][baseUV.y + rndOffset.y][0];
        uvec2 LP1 = lds[baseUV.x + rndOffset.x][baseUV.y + rndOffset.y][1];
        uvec2 LP2 = lds[baseUV.x + rndOffset.x][baseUV.y + rndOffset.y][2];
        ssll_clusterData cluster = unpackCluster(LP0, LP1, LP2);
        
        
        float clusterDistance = max(cluster.radius, distance(cluster.center, position));
        float clusterCos = max(0.0, dot(normal, cluster.avgNormal)) * (cluster.normalLength + 0.1); //TODO: Merge normal and its length
        float ww = clusterCos / clusterDistance;
        
        float geometryW = geometryWeight(position, normal, cluster.normal, cluster.uv, cluster.depth);
        
        float w = geometryW * cluster.LOS * ww;
        
        wwsum += ww;
        wsum += w;
        
        if (rnd(seed) < w / wsum || wsum == 0) {
            rLight = cluster;
            lW = w;
            lWW = ww;
        }
    }
    
    wwsum /= N;
    
    float pdf = wwsum/lWW;
    
    float lightWeightQ = rLight.LOS;
    uint Q = getQ(pow(lightWeightQ, 0.2));
    float qWeight = getQweight(Q);
    uint lCount = ssllCounters[0];
    float wMax = uintBitsToFloat(ssllCounters[1]);
    float wSum = ssllCounters[2] * exp2(-b) + ssllCounters[3] * exp2(32 - b);
    uint targetCount = uint(resolution.x * resolution.y * targetCoverage);
    float eCount = wSum / wMax;
    float coverageP = qWeight / wMax;
    if (eCount > targetCount) coverageP *= targetCount / eCount;
    
    
    float selectionP = N;
    float reservoirP = lW / wsum;

    float clusterSelectionP = clusterN / float(totalLights);
    float clusterReservoirP = rLight.P;
    
    pdf *= coverageP;
    pdf *= clusterSelectionP;
    pdf *= clusterReservoirP;
    pdf *= selectionP;
    pdf *= reservoirP;
    
    float lightWeight = 1.0 / pdf;
    if (wsum == 0.0) lightWeight = 0.0;
    
    //lightWeight *= step(32, distance(gl_GlobalInvocationID.xy, rLight.uv));
    
    ssll_LightSource light;
    light.uv = rLight.uv;
    light.LOS = rLight.LOS;
    light.weight = lightWeight;
    light.depth = rLight.depth;
    light.normal = rLight.normal;
    return light;
}

radianceSeparate ssll_ResolveSample(vec3 position, ssll_LightSource light, uvec3 surface) {
    
    vec3 lightPos = projectPoint(vec3((light.uv + 0.5) * resolutionInv, light.depth) * 2.0 - 1.0, gbufferProjectionInverse);
    vec3 lightDir = normalize(lightPos - position);
    float r = distance(position, lightPos);
    
    float geometryW = max(0.0, dot(lightDir, getNormal(surface))) * max(0.0, dot(light.normal, -lightDir)) / (r*r);
    
    radianceSeparate brdf = BRDF(lightDir, -normalize(position), surface);
    
    vec3 lightEmission = texelFetch(colortex2, light.uv, 0).rgb;
    vec3 lightOutput = light.LOS * lightEmission / dot(lightEmission, vec3(2048));
    
    lightOutput *= geometryW;
    lightOutput *= light.weight;
    
    if (light.weight == 0.0) return radianceSeparate(vec3(0), vec3(0));
    
    return radianceSeparate(lightOutput * brdf.diffuse, lightOutput * brdf.specular);
}

float ssll_ResolveSample(vec3 position, ssll_LightSource light, vec3 normal) {
    
    vec3 lightPos = projectPoint(vec3((light.uv + 0.5) * resolutionInv, light.depth) * 2.0 - 1.0, gbufferProjectionInverse);
    vec3 lightDir = normalize(lightPos - position);
    float r = distance(position, lightPos);
    
    float geometryW = max(0.0, dot(lightDir, normal)) * max(0.0, dot(light.normal, -lightDir)) / (r);
    float lightW = light.LOS * geometryW * light.weight;
    
    return lightW;
}

#endif