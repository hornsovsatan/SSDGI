/*
 * All Rights Reserved
 * 
 * Copyright (c) 2024-2026 lipesto
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


//////////////////////////////////////////////////
//██//////██//██████████//██//////██////████████//
//██//////██//////██////////██//██////██//////////
////██//██////////██//////////██////////██████////
////██//██////////██////////██//██////////////██//
//////██//////////██//////██//////██//████████////
//////////////////////////////////////////////////

#define HIZ_BUFFER hiZtex
#define SECONDARY_DEPTH_BUFFER depthtex1

float hizLod2Offset;
float hizLod3Offset;
int hizLod3EarlyOffset;
int hizLod3EarlyOffset2;
int hizZWidthOffset;

float edgeFade(vec2 hit) {
    vec2 edgeDistPixels = min(hit, resolution - hit);
    float minDistPixels = min(1.0, min(edgeDistPixels.x, edgeDistPixels.y) * 0.05);
    return pow(saturate(minDistPixels), 0.5);
}
float edgeFade(vec2 hit, vec2 o) {
    float d = min(distance(hit, o), min(resolution.x, resolution.y) * 0.5);
    vec2 edgeDistPixels = min(hit, resolution - hit);
    float minDistPixels = min(1.0, min(edgeDistPixels.x, edgeDistPixels.y) * 4.0 / d);
    return minDistPixels * minDistPixels;
}

vec3 intersectScreenEdge(vec3 O, vec3 origin, vec3 direction) {
    float zLimit = min(1e9, (direction.z < 0.0 ? origin.z + far * 4.0 : -origin.z - near) / direction.z);
    vec3 F = projectPoint(origin + direction * zLimit, gbufferProjection) * 0.5 + 0.5;
    vec3 D = F - O;
    
    vec2 border = fract(-sign(D.xy) * O.xy) / abs(D.xy);
    D *= min(1.0, min(border.x, border.y));
    return D;
}

vec3 lerpRefinement(vec3 P, vec3 rayStep) {
    vec3 p0 = P - rayStep * 2.0;
    vec3 p1 = P + rayStep * 2.0;
    float d0 = texelFetch(SECONDARY_DEPTH_BUFFER, ivec2(p0.xy), 0).r;
    float d1 = texelFetch(SECONDARY_DEPTH_BUFFER, ivec2(p1.xy), 0).r;
    float z0 = d0-p0.z;
    float z1 = d1-p1.z;
    float f = (z0/(z0-z1));
    if (f == clamp(f, -0.5, 1.5)) return P = mix(p0, p1, f);
    return P;
}

float intersectGrid(vec2 P, vec2 rayStep) {
    bool xAxis = abs(rayStep.x) > abs(rayStep.y);
    vec2 edges = -sign(rayStep) * P;
    return fract(xAxis ? edges.x : edges.y);
}

uint ssrt_TraverseLOD3(vec3 P, vec3 rayStep, uint maxSteps) {
    P.xy /= 16;
    rayStep.z *= 16;
    
    P.y += hizLod3Offset;
    P += rayStep * 0.5;
    P.z += abs(rayStep.z) * 0.5;
    P.z -= rayStep.z;
    
    P.xy += 8192.0;
    
    uint bitmask = 0;
    
    for (uint head = 1u << (32 - maxSteps); head!=0; head <<= 1){
        ivec2 uv = (floatBitsToInt(P.xy) & 0x007ffc00) >> 10;
        float screenDepthMin = texelFetch(HIZ_BUFFER, uv, 0).r;
        uv.x += hizLod3EarlyOffset;
        float screenDepthMax = texelFetch(HIZ_BUFFER, uv, 0).r;
        
        #ifdef CNVS
        setPixelTestLod3((floatBitsToInt(P.xy ) & 0x007ffc00) >> 10, screenDepthMin <= P.z + rayStep.z, 0.2);
        #endif
        
        P += rayStep;
        
        float zMin = P.z - abs(rayStep.z);
        if (screenDepthMin <= P.z) bitmask |= head; 
        if (screenDepthMax < zMin) break;
        
    }
    bitmask >>= (32 - maxSteps);
    return bitmask;
}

uint ssrt_TraverseSegment(vec3 P, vec3 rayStep) {
    vec3 P1 = P + rayStep * 1.0;
    vec3 P2 = P + rayStep * 2.0;
    vec3 P3 = P + rayStep * 3.0;
    float d0 = texelFetch(HIZ_BUFFER, (floatBitsToInt(P.xy ) & 0x007ffc00) >> 10, 0).r;
    float d1 = texelFetch(HIZ_BUFFER, (floatBitsToInt(P1.xy) & 0x007ffc00) >> 10, 0).r;
    float d2 = texelFetch(HIZ_BUFFER, (floatBitsToInt(P2.xy) & 0x007ffc00) >> 10, 0).r;
    float d3 = texelFetch(HIZ_BUFFER, (floatBitsToInt(P3.xy) & 0x007ffc00) >> 10, 0).r;
    uint segment = uint(d0 <= P.z);     
    segment |= uint(d1 <= P1.z) << 1;   
    segment |= uint(d2 <= P2.z) << 2;   
    segment |= uint(d3 <= P3.z) << 3;   
    #ifdef CNVS
    setPixelTestLod2((floatBitsToInt(P.xy ) & 0x007ffc00) >> 10, d0 <= P.z, 0.3);
    setPixelTestLod2((floatBitsToInt(P1.xy) & 0x007ffc00) >> 10, d1 <= P1.z, 0.3);
    setPixelTestLod2((floatBitsToInt(P2.xy) & 0x007ffc00) >> 10, d2 <= P2.z, 0.3);
    setPixelTestLod2((floatBitsToInt(P3.xy) & 0x007ffc00) >> 10, d3 <= P3.z, 0.3);
    #endif
    return segment;
}
uint ssrt_TraverseLOD2(vec3 O, vec3 rayStep, inout uint lod3Mask) {
    
    O.xy /= 4;
    rayStep.z *= 4;
    
    O.y += hizLod2Offset;
    O += rayStep * 0.5;
    O.z += abs(rayStep.z) * 0.375;
    O.xy += 8192.0;
    
    vec3 P;
    uint topMask = lod3Mask;
    uint bitmask = 0;
    uint headOffset = 0;
    while(topMask != 0 && headOffset<32) {
        int offset = findLSB(topMask);
        vec3 P = O + rayStep * offset * 4;
        uint segment = ssrt_TraverseSegment(P, rayStep);
        
        bitmask |= segment << headOffset;
        
        uint sub = topMask - 1;
        topMask &= sub;
        if (segment == 0) lod3Mask &= sub;
        else headOffset += 4;
    }
    
    return bitmask;
}

bool ssrt_TraverseLOD1(inout vec3 P, vec3 rayStep, inout uint lod3Mask, uint lod2Mask) {
    P += rayStep * 0.5;
    
    vec3 O = P;
    int segmentID = 0;
    int globalOffset = findLSB(lod3Mask);
    
    float si = 4.0;
    float offset;
    while (lod2Mask != 0) {
        int localOffset = findLSB(lod2Mask);
        
        if (localOffset>>2 != segmentID) {
            segmentID++;
            lod3Mask &= lod3Mask - 1;
            globalOffset = findLSB(lod3Mask);
        }
        offset = float((globalOffset << 2) | (localOffset & 3)) * 4.0;
        
        P = O + rayStep * offset;
        
        vec3 P1 = P + rayStep * 1.0;
        vec3 P2 = P + rayStep * 2.0;
        vec3 P3 = P + rayStep * 3.0;
        float d0 = texelFetch(HIZ_BUFFER, ivec2(P ), 0).r;
        float d1 = texelFetch(HIZ_BUFFER, ivec2(P1), 0).r;
        float d2 = texelFetch(HIZ_BUFFER, ivec2(P2), 0).r;
        float d3 = texelFetch(HIZ_BUFFER, ivec2(P3), 0).r;
        if (d0 <= P.z ) {si = 0.0; break;}
        if (d1 <= P1.z) {si = 1.0; break;}
        if (d2 <= P2.z) {si = 2.0; break;}
        if (d3 <= P3.z) {si = 3.0; break;}
        
        lod2Mask &= lod2Mask - 1;
    }
    P = O + rayStep * (offset + si);
    lod3Mask &= lod3Mask - 1;
    return (lod2Mask != 0);
}

bool ssrt_TraversePrimary(inout vec3 P, vec3 rayStep, int raySteps){
    P.xy += rayStep.xy;
    P.xy += 8192.0;
    int i;
    for (i = 0; i<raySteps; i++) {
        float screenDepth = texelFetch(HIZ_BUFFER, (floatBitsToInt(P.xy) & 0x007ffc00) >> 10, 0).r;
        P += rayStep;
        if (screenDepth <= P.z) break; 
        #ifdef CNVS
        setPixelLod1((floatBitsToInt(P.xy) & 0x007ffc00) >> 10, vec4(0.2,0.2,1,.8));
        #endif
        
    }
    P.xy -= 8192.0;
    P.xy -= rayStep.xy;
    return (i != raySteps);
}

bool ssrt_TraverseSecondary(inout vec3 P, vec3 rayStep, int raySteps){
    P.xy += rayStep.xy;
    int i;
    for (i = 0; i<raySteps; i++) {
        float screenDepth = texelFetch(SECONDARY_DEPTH_BUFFER, ivec2(P), 0).r;
        P += rayStep;
        if (screenDepth <= P.z) break;
    }
    P.xy -= rayStep.xy;
    return (i != raySteps);
}

vec4 ssrt_Ray(vec3 wO, vec3 wD, vec3 O, bool needsRefinement, float widthTolerance) {
    O.xy *= resolutionInv;
    vec3 D = intersectScreenEdge(O, wO, wD);
    vec3 P = O;
    
    D.xy *= resolution;
    P.xy *= resolution;
    
    float rayLength = max(abs(D.x), abs(D.y));
    vec3 rayStep = D / rayLength;
    int raySteps = int(rayLength);
    
    P += rayStep;
    raySteps--;
    
    bool secondaryHit = ssrt_TraverseSecondary(P, rayStep, min(5, raySteps));
    raySteps -= 5;
    
    if (raySteps <= 0) return vec4(P, 0);
    
    rayStep.z *= HIZ_PIXEL_SIZE;
    P.xy /= HIZ_PIXEL_SIZE;
    raySteps /= HIZ_PIXEL_SIZE;
    
    float opacity = 1.0;
    if (!secondaryHit) {
        float gridDistance = intersectGrid(P.xy / 16, rayStep.xy) * 16;
        
        vec3 eO = P + rayStep * gridDistance;
        
        P += rayStep * (fract(gridDistance) - 0.5); //PIZDEC
        
        int preSteps = min(raySteps, int(gridDistance));
        bool preTraverseHit = ssrt_TraversePrimary(P, rayStep, preSteps);
        raySteps -= preSteps;
        if (!preTraverseHit) {
            P = eO;
            int lod3Steps = int(min(32,ceil(raySteps / 16.0)));
            uint lod3Mask = ssrt_TraverseLOD3(eO, rayStep, lod3Steps);
            uint lod2Mask = ssrt_TraverseLOD2(eO, rayStep, lod3Mask);
            if (lod3Mask!=0) {
            bool hit = ssrt_TraverseLOD1(P, rayStep, lod3Mask, lod2Mask);
            if (!hit) {
                opacity = 0;
                P = eO + rayStep * 16 * min(uint(findLSB(lod3Mask)), lod3Steps);
            }
            } else {
                P = eO + rayStep * 16 * lod3Steps;
                opacity = 0.0;
            }
        }
    }
    
    #ifdef CNVS
    setPixelLod1(ivec2(P), vec4(1));
    #endif
    
    P.xy *= HIZ_PIXEL_SIZE;
    rayStep.z /= HIZ_PIXEL_SIZE;
    
    if (opacity != 0.0) {
        //float fWidth = texelFetch(HIZ_BUFFER, ivec2(P / HIZ_PIXEL_SIZE) + ivec2(ceil(resolution.x / HIZ_PIXEL_SIZE), 0), 0).r;
        float fWidth = float(texelFetch(colortex3, ivec2(P / HIZ_PIXEL_SIZE) * HIZ_PIXEL_SIZE, 0).r >> 16) / float(0xFFFF) / Z_WIDTH_SCALE * HIZ_PIXEL_SIZE;
        
        float screenDepth = texelFetch(SECONDARY_DEPTH_BUFFER, secondaryHit ? ivec2(P) :ivec2(P / HIZ_PIXEL_SIZE) * HIZ_PIXEL_SIZE + (HIZ_PIXEL_SIZE/2), 0).r;
        float backDistance = P.z - abs(rayStep.z * HIZ_PIXEL_SIZE) - fWidth - screenDepth;
        opacity *= mix(1.0, 0.0, clamp(sqrt(backDistance) * 90, 0.0, 1.0));
        if (backDistance > 0) opacity = 0.0;
        
        float opacityFaloff = max(0.0, 1.0 - fWidth * widthTolerance);
        opacity *= opacityFaloff * opacityFaloff;
        
        if (P.xy != clamp(P.xy, vec2(0), resolution)) {
            opacity = 0.0;
            O.xy *= resolution;
            P = O + D;   
        }
        
        if (!secondaryHit && needsRefinement) P = lerpRefinement(P, rayStep);
    }
    
    return vec4(P, opacity);
}


bool ssrt_CheckVisibilityFast(vec3 P, vec3 F) {
    F.z -= 0.001;
    vec3 D = F-P;
    
    P.xy /= HIZ_PIXEL_SIZE * 16;
    D.xy /= HIZ_PIXEL_SIZE * 16;
    
    float rayLength = max(abs(D.x), abs(D.y));
    vec3 rayStep = D / rayLength;
    int raySteps = int(rayLength);
    
    float gridDistance = intersectGrid(P.xy, rayStep.xy);
    
    P += rayStep * (gridDistance + 0.5);
    raySteps = int(rayLength - (gridDistance + 0.5));
    
    P.xy += vec2(hizLod3EarlyOffset, hizLod3Offset);
    P.z -= abs(rayStep.z);
    P.z -= rayStep.z;
    
    raySteps = min(raySteps, 32);
    for (int i = 0; i<raySteps; i++) {
        float screenDepthMin = texelFetch(HIZ_BUFFER, ivec2(P), 0).r;
        P += rayStep;
        if (screenDepthMin < P.z) return false;
    }
    return true;
    
}

bool ssrt_TraverseLOD3EarlyHit(vec3 P, vec3 rayStep, uint maxSteps, out uint bitmask) {
    P.xy /= 16;
    rayStep.z *= 16;
    
    P.y += hizLod3Offset;
    P += rayStep * 0.5;
    P.z += abs(rayStep.z) * 0.5;
    P.z -= rayStep.z;
    
    P.xy += 8192.0;
    
    bitmask = 0;
    
    
    for (uint head = 1u << (32 - maxSteps); head!=0; head <<= 1){
        ivec2 uv = (floatBitsToInt(P.xy) & 0x007ffc00) >> 10;
        float screenDepthMin = texelFetch(HIZ_BUFFER, uv, 0).r;
        uv.x += hizLod3EarlyOffset;
        float screenDepthMax = texelFetch(HIZ_BUFFER, uv, 0).r;
        
        #ifdef CNVS
        setPixelTestLod3((floatBitsToInt(P.xy ) & 0x007ffc00) >> 10, screenDepthMin <= P.z + rayStep.z, 0.2);
        #endif
        
        P += rayStep;
        
        float zMin = P.z - abs(rayStep.z);
        if (screenDepthMin <= P.z) bitmask |= head; 
        if (screenDepthMax < zMin) return true;
        
    }
    bitmask >>= (32 - maxSteps);
    return false;
}

bool ssrt_CheckVisibility(vec3 P, vec3 F) {
    P.z -= 1.0/65535.0;
    vec3 D = F-P;
    
    float rayLength = max(abs(D.x), abs(D.y));
    vec3 rayStep = D / rayLength;
    int raySteps = int(rayLength) - 1;
    
    P += rayStep;
    raySteps--;
    
    bool secondaryHit = ssrt_TraverseSecondary(P, rayStep, min(raySteps, 6));
    raySteps -= 6;
    if (secondaryHit) return false;
    if (raySteps <= 0) return true;
    
    rayStep.z *= HIZ_PIXEL_SIZE;
    P.xy /= HIZ_PIXEL_SIZE;
    raySteps /= HIZ_PIXEL_SIZE;
    
    
    float gridDistance = intersectGrid(P.xy / 16, rayStep.xy) * 16;
    
    vec3 eO = P + rayStep * gridDistance;
    
    //align P with grid
    P += rayStep * (fract(gridDistance) - 0.5);
    
    int preSteps = min(raySteps, int(gridDistance + 1));
    bool preTraverseHit = ssrt_TraversePrimary(P, rayStep, preSteps);
    raySteps -= preSteps;
    if (preTraverseHit) return false;
    if (raySteps <= 0) return true;
    
    int lod3Steps = int(min(32, trunc(raySteps / 16.0)));    
    if (lod3Steps > 0) {
        P = eO;
        uint lod3Mask;
        bool earlyHit = ssrt_TraverseLOD3EarlyHit(eO, rayStep, lod3Steps, lod3Mask);
        if (earlyHit) return false;
        if (lod3Mask != 0u) {
            uint lod2Mask = ssrt_TraverseLOD2(eO, rayStep, lod3Mask);
            if (lod3Mask != 0u) {
                bool lod1Hit = ssrt_TraverseLOD1(P, rayStep, lod3Mask, lod2Mask);
                if (lod1Hit) return false;
            }
        }
    }
    
    P = eO + rayStep * (lod3Steps * 16 - 0.5);
    
    int postSteps = min(raySteps - (lod3Steps * 16), 16);
    bool postTraverseHit = ssrt_TraversePrimary(P, rayStep, postSteps);
    if (postTraverseHit) return false;
    
    return true;
}

bool ssrt_TraverseLOD3EarlyHit2(vec3 P, vec3 rayStep, uint maxSteps, out uint bitmask) {
    P.xy /= 16;
    rayStep.z *= 16;
    
    P.y += hizLod3Offset;
    P += rayStep * 0.5;
    P.z += abs(rayStep.z) * 0.5;
    P.z -= rayStep.z;
    
    P.xy += 8192.0;
    
    bitmask = 0;
    
    
    for (uint head = 1u << (32 - maxSteps); head!=0; head <<= 1){
        ivec2 uv = (floatBitsToInt(P.xy) & 0x007ffc00) >> 10;
        float screenDepth = texelFetch(HIZ_BUFFER, uv, 0).r;
        float screenDepth1 = texelFetch(HIZ_BUFFER, uv + ivec2(hizLod3EarlyOffset2, 0), 0).r;
        
        #ifdef CNVS
        setPixelTestLod3((floatBitsToInt(P.xy ) & 0x007ffc00) >> 10, screenDepthMin <= P.z + rayStep.z, 0.2);
        #endif
        
        P += rayStep;
        
        float zMin = P.z - abs(rayStep.z);
        if (screenDepth <= P.z && P.z - abs(rayStep.z) <= screenDepth1) bitmask |= head; 
        //if (screenDepthMax < zMin) return true;
        
    }
    bitmask >>= (32 - maxSteps);
    return false;
}


bool ssrt_TraverseSecondary2(inout vec3 P, vec3 rayStep, int raySteps){
    P.xy += rayStep.xy;
    
    P.z += abs(rayStep.z) * 0.5;
    
    int i;
    for (i = 0; i<raySteps; i++) {
        float screenDepth = texelFetch(SECONDARY_DEPTH_BUFFER, ivec2(P), 0).r;
        float zwidth = float(texelFetch(colortex3, ivec2(P), 0).r >> 16) / (float(0xFFFF) * Z_WIDTH_SCALE);
        P += rayStep;
        
        if (screenDepth + zwidth > P.z - abs(rayStep.z) && screenDepth < P.z) break;
        
        //if (screenDepth <= P.z && screenDepth > P.z - 0.0002) break;
    }
    P.z -= abs(rayStep.z) * 0.5;
    P.xy -= rayStep.xy;
    return (i != raySteps);
}

bool ssrt_TraversePrimary2(inout vec3 P, vec3 rayStep, int raySteps){
    
    P.z += abs(rayStep.z) * 0.5;
    P.xy += rayStep.xy;
    P.xy += 8192.0;
    int i;
    for (i = 0; i<raySteps; i++) {
        ivec2 iP = (floatBitsToInt(P.xy) & 0x007ffc00) >> 10;
        
        float screenDepth0 = texelFetch(HIZ_BUFFER, iP, 0).r;
        float screenDepth1 = texelFetch(HIZ_BUFFER, iP + ivec2(hizZWidthOffset, 0), 0).r;
        P += rayStep;
        
        if (screenDepth1 > P.z - abs(rayStep.z) && screenDepth0 < P.z) break;
    }
    P.xy -= 8192.0;
    P.xy -= rayStep.xy;
    P.z -= abs(rayStep.z) * 0.5;
    return i != raySteps;
}

bool ssrt_TraverseLOD1_2(inout vec3 P, vec3 rayStep, inout uint lod3Mask, uint lod2Mask) {
    P += rayStep * 0.5;
    P.z -= abs(rayStep.z) * 0.5;
    
    vec3 O = P;
    int segmentID = 0;
    int globalOffset = findLSB(lod3Mask);
    
    float si = 4.0;
    float offset;
    while (lod2Mask != 0) {
        int localOffset = findLSB(lod2Mask);
        
        if (localOffset>>2 != segmentID) {
            segmentID++;
            lod3Mask &= lod3Mask - 1;
            globalOffset = findLSB(lod3Mask);
        }
        offset = float((globalOffset << 2) | (localOffset & 3)) * 4.0;
        
        P = O + rayStep * offset;
        
        vec3 P1 = P + rayStep * 1.0;
        vec3 P2 = P + rayStep * 2.0;
        vec3 P3 = P + rayStep * 3.0;
        float d00 = texelFetch(HIZ_BUFFER, ivec2(P ), 0).r;
        float d01 = texelFetch(HIZ_BUFFER, ivec2(P ) + ivec2(hizZWidthOffset, 0), 0).r;
        float d10 = texelFetch(HIZ_BUFFER, ivec2(P1), 0).r;
        float d11 = texelFetch(HIZ_BUFFER, ivec2(P1) + ivec2(hizZWidthOffset, 0), 0).r;
        float d20 = texelFetch(HIZ_BUFFER, ivec2(P2), 0).r;
        float d21 = texelFetch(HIZ_BUFFER, ivec2(P2) + ivec2(hizZWidthOffset, 0), 0).r;
        float d30 = texelFetch(HIZ_BUFFER, ivec2(P3), 0).r;
        float d31 = texelFetch(HIZ_BUFFER, ivec2(P3) + ivec2(hizZWidthOffset, 0), 0).r;
        if (d01 > P.z  && d00 < P.z  + abs(rayStep.z)) {si = 0.0; break;}
        if (d11 > P1.z && d10 < P1.z + abs(rayStep.z)) {si = 1.0; break;}
        if (d21 > P2.z && d20 < P2.z + abs(rayStep.z)) {si = 2.0; break;}
        if (d31 > P3.z && d30 < P3.z + abs(rayStep.z)) {si = 3.0; break;}
        
        lod2Mask &= lod2Mask - 1;
    }
    P = O + rayStep * (offset + si);
    P.z += abs(rayStep.z) * 0.5;
    lod3Mask &= lod3Mask - 1;
    return (lod2Mask != 0);
}

float ssrt_CheckVisibilityGT(vec3 P, vec3 F) { //return true;
    vec3 D = F-P;
    
    float rayLength = max(abs(D.x), abs(D.y));
    vec3 rayStep = D / rayLength;
    int raySteps = int(rayLength) - 1;
    
    //P += rayStep;
    //raySteps--;
    
    bool secondaryHit = ssrt_TraverseSecondary2(P, rayStep, min(raySteps, 8));
    raySteps -= 8;
    if (secondaryHit) return 0.0;
    
    rayStep.z *= HIZ_PIXEL_SIZE;
    P.xy /= HIZ_PIXEL_SIZE;
    raySteps /= HIZ_PIXEL_SIZE;
    
    float gridDistance = intersectGrid(P.xy / 16, rayStep.xy) * 16;
    
    vec3 eO = P + rayStep * gridDistance;
    
    //align P with grid
    P += rayStep * (fract(gridDistance) - 1.5);
    
    int preSteps = min(raySteps, int(gridDistance));
    
    bool primaryHit = ssrt_TraversePrimary2(P, rayStep, raySteps);
    
    return float(!primaryHit);
}

bool ssrt_CheckVisibilityThickness(vec3 P, vec3 F) { //return true;
    P.z -= 1.0/65535.0;
    vec3 D = F-P;
    
    float rayLength = max(abs(D.x), abs(D.y));
    vec3 rayStep = D / rayLength;
    int raySteps = int(rayLength) - 1;
    
    P += rayStep;
    raySteps--;
    
    bool secondaryHit = ssrt_TraverseSecondary2(P, rayStep, min(raySteps, 6));
    raySteps -= 6;
    if (secondaryHit) return false;
    if (raySteps <= 0) return true;
    
    rayStep.z *= HIZ_PIXEL_SIZE;
    P.xy /= HIZ_PIXEL_SIZE;
    raySteps /= HIZ_PIXEL_SIZE;
    
    
    float gridDistance = intersectGrid(P.xy / 16, rayStep.xy) * 16;
    
    vec3 eO = P + rayStep * gridDistance;
    
    //align P with grid
    P += rayStep * (fract(gridDistance) - 1.5);
    
    int preSteps = min(raySteps, int(gridDistance + 1));
    bool preTraverseHit = ssrt_TraversePrimary2(P, rayStep, preSteps);
    raySteps -= preSteps;
    if (preTraverseHit) return false;
    if (raySteps <= 0) return true;
    
    int lod3Steps = int(min(32, trunc(raySteps / 16.0)));
    if (lod3Steps > 0) {
        P = eO;
        uint lod3Mask;
        ssrt_TraverseLOD3EarlyHit2(eO, rayStep, lod3Steps, lod3Mask);
        if (lod3Mask != 0u) {
            uint lod2Mask = ssrt_TraverseLOD2(eO, rayStep, lod3Mask);
            if (lod3Mask != 0u) {
                bool lod1Hit = ssrt_TraverseLOD1_2(P, rayStep, lod3Mask, lod2Mask);
                if (lod1Hit) return false;
            }
        }
    }
    P = eO + rayStep * (lod3Steps * 16 - 0.5);
    
    int postSteps = min(raySteps - (lod3Steps * 16), 16);
    bool postTraverseHit = ssrt_TraversePrimary2(P, rayStep, postSteps);
    if (postTraverseHit) return false;
    
    return true;
}
