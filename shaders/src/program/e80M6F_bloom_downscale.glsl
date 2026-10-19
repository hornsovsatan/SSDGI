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

#ifdef VERTEX

uniform vec2 resolution;
uniform vec2 resolutionInv;

#include "/src/utils/bloom_tiles.glsl"

noperspective out vec2 uv;
flat out vec4 bounds;

void main() {
    vec4 p = getTile(PASS_ID + 1, false) * vec4(resolutionInv, resolutionInv) * 2.0 - 1.0;
    gl_Position = vec4(vec2[](p.xy, p.zy, p.zw, p.xw)[gl_VertexID], 0.0, 1.0);
    
    vec4 u = getTile(PASS_ID, true) * vec4(resolutionInv, resolutionInv);
    uv = vec2[](u.xy, u.zy, u.zw, u.xw)[gl_VertexID];
    
    bounds = (getTile(PASS_ID, false) + vec4(0.5, 0.5, -0.5, -0.5)) * vec4(resolutionInv, resolutionInv);
}

#endif
#ifdef FRAGMENT

noperspective in vec2 uv;
flat in vec4 bounds;

uniform sampler2D colortex2;
uniform vec2 resolutionInv;

/* RENDERTARGETS: 2 */
layout(location = 0) out vec3 color;

// Based on Sledgehammer Games' bloom used for Call of Duty: Advanced Warfare

void main() {
    vec3 a = textureLod(colortex2, clamp(uv + vec2(-2, 2) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    vec3 b = textureLod(colortex2, clamp(uv + vec2( 0, 2) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    vec3 c = textureLod(colortex2, clamp(uv + vec2( 2, 2) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    
    vec3 d = textureLod(colortex2, clamp(uv + vec2(-2, 0) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    vec3 e = textureLod(colortex2, clamp(uv + vec2( 0, 0) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    vec3 f = textureLod(colortex2, clamp(uv + vec2(-2, 0) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    
    vec3 g = textureLod(colortex2, clamp(uv + vec2(-2,-2) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    vec3 h = textureLod(colortex2, clamp(uv + vec2( 0,-2) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    vec3 i = textureLod(colortex2, clamp(uv + vec2( 2,-2) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    
    vec3 j = textureLod(colortex2, clamp(uv + vec2(-1, 1) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    vec3 k = textureLod(colortex2, clamp(uv + vec2( 1, 1) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    vec3 l = textureLod(colortex2, clamp(uv + vec2(-1,-1) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    vec3 m = textureLod(colortex2, clamp(uv + vec2( 1,-1) * resolutionInv, bounds.xy, bounds.zw), 0).rgb;
    
    color = e*0.125;
    color += (a+c+g+i)*0.03125;
    color += (b+d+f+h)*0.0625;
    color += (j+k+l+m)*0.125;
}

#endif