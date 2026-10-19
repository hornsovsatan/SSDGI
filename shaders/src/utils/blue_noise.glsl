/*
 * All Rights Reserved
 * 
 * Copyright (c) 2026 lipesto
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
 
#ifndef BLUE_NOISE
#define BLUE_NOISE
#include "/src/utils/random.glsl"

uniform sampler3D bluenoisetex;

ivec3 bn_wrapCoords(ivec3 coord) {
    coord.xy += ivec2(r2(coord.z >> 3) * 128);
    return ivec3(coord.xy & 127, coord.z & 15);
}

vec4 blueNoise(ivec3 coord) {
    vec4 s = texelFetch(bluenoisetex, bn_wrapCoords(coord), 0);
    s.xyz = normalize(s.xyz * 2.0 - 1.0);
    return s;
}

vec3 blueNoiseCosineHemisphere(ivec3 coord) {
  return normalize(texelFetch(bluenoisetex, bn_wrapCoords(coord), 0).rgb * 2.0 - 1.0);
}

vec2 blueNoiseCircle(ivec3 coord) {
    return texelFetch(bluenoisetex, bn_wrapCoords(coord), 0).rg * 2.0 - 1.0;
}

float blueNoiseScalar(ivec3 coord) {
    return texelFetch(bluenoisetex, bn_wrapCoords(coord), 0).a;
}



#endif