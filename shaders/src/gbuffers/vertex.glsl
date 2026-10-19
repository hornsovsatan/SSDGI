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

#include "/src/utils/storage.glsl"

mat3 buildTBN(vec3 normal, vec4 tangent) {
    normal =  normalize(gl_NormalMatrix * normal);
    tangent.xyz = normalize(gl_NormalMatrix * tangent.xyz);
    mat3 TBN = mat3(tangent.xyz, normalize(cross(tangent.xyz, normal) * tangent.w), normal);
    return TBN;
}

uvec4 packTBN(mat3 TBN) {
    uvec4 pack;
    pack.x = packSnorm2x16(TBN[2].xy);
    pack.y = packSnorm2x16(TBN[0].xy);
    pack.z = packSnorm2x16(TBN[1].xy);
    pack.w = packSnorm2x16(vec2(TBN[0].z, TBN[1].z));
    return pack;
}

vec2 getAtlasCoordinates() {
    return (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

vec2 getLightmapCoordinates() {
    vec2 coords = ((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy * (16.0/13.0) - (1.0/13.0));
    coords.y *= coords.y;
    return coords;
}

vec2 getQuadCoordinates() {
    return mat4x2(1,1, 0,1, 0,0, 1,0)[gl_VertexID&3];
}

uint getNormalPack() {
    vec3 N = gl_NormalMatrix * gl_Normal;
    return packSnorm2x16(octaEncode(N));
}

vec3 getTangentPack(vec4 tangent) {
    vec3 T = normalize(gl_NormalMatrix * tangent.xyz);
    T.z += tangent.w * 1.5 + 1.5;
    return T;
}
