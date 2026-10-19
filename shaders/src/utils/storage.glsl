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

#ifndef STORAGE
#define STORAGE

vec2 fsign(vec2 x) {
    return uintBitsToFloat((floatBitsToUint(x) & 0x80000000u) | 0x3f800000u);
}

vec2 octaEncode(vec3 normal) { 
    normal.xy /= dot(abs(normal), vec3(1.0));
    if (normal.z < 0.0) normal.xy = fsign(normal.xy) * (1.0 - abs(normal.yx));
    return normal.xy;
}

vec3 octaDecode(vec2 normal) {
    float z = 1.0 - abs(normal.x) - abs(normal.y);
    return vec3(fma(min(z, 0.0).xx, fsign(normal), normal), z);
}

uvec2 packGeometryData(float viewZ, vec3 normal, float roughness) {
    uint z = floatBitsToUint(-viewZ)>>7;
    uint r = uint(roughness * 255.0 + 0.5);
    uint n = packSnorm2x16(octaEncode(normal)); //wtf
    return uvec2(z | (r<<24), n);
}

void unpackGeometryData(uvec2 pack, out vec3 normal, out float viewZ, out float roughness) {
    normal = normalize(octaDecode(unpackSnorm2x16(pack.y)));
    viewZ = -uintBitsToFloat((pack.x&0x00FFFFFF)<<7);
    roughness = float(pack.x>>24) / 255.0;
}

#endif