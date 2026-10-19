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

#include "/properties/iris_constants.glsl"
#include "/properties/buffer_settings.glsl"
#include "/properties/shadow_settings.glsl"
#include "/properties/shader_settings.glsl"
#include "/properties/post_settings.glsl"
#include "/properties/rt_settings.glsl"




uniform sampler2D depthtex1;
uniform sampler2D colortex0;
uniform sampler2D colortex9;
uniform usampler2D colortex3;

uniform sampler2D denoiserCh0t;
uniform sampler2D denoiserCh1t;
uniform sampler2D denoiserESt;


vec4 unpackEdge(uint e) {
    e &= 0xFFu;
    float m = (e>>2) / 62.0;
    vec4 d = vec4(0.5);
    d[e&3u] = m;
    return d;
}
float unpackEdgeI(uint e, uint i) {
    e &= 0xFFu;
    float m = (e>>2) / 62.0;
    return (e&3u) == i ? m : 0.5;
}

out vec3 color;

void main() {
    color = texelFetch(colortex0, ivec2(gl_FragCoord),0).rgb;
    
    
    #if AA > 0
    vec4 edge = unpackEdge(texelFetch(colortex3, ivec2(gl_FragCoord),0).r);
    float depth = texelFetch(depthtex1, ivec2(gl_FragCoord),0).r;
    
    float d0 = texelFetch(depthtex1, ivec2(gl_FragCoord) + ivec2( 1, 0),0).r;
    float d1 = texelFetch(depthtex1, ivec2(gl_FragCoord) + ivec2(-1, 0),0).r;
    float d2 = texelFetch(depthtex1, ivec2(gl_FragCoord) + ivec2( 0, 1),0).r;
    float d3 = texelFetch(depthtex1, ivec2(gl_FragCoord) + ivec2( 0,-1),0).r;
    
    float e0 = unpackEdgeI(texelFetch(colortex3, ivec2(gl_FragCoord) + ivec2( 1, 0),0).r, 1);
    float e1 = unpackEdgeI(texelFetch(colortex3, ivec2(gl_FragCoord) + ivec2(-1, 0),0).r, 0);
    float e2 = unpackEdgeI(texelFetch(colortex3, ivec2(gl_FragCoord) + ivec2( 0, 1),0).r, 3);
    float e3 = unpackEdgeI(texelFetch(colortex3, ivec2(gl_FragCoord) + ivec2( 0,-1),0).r, 2);
    
    if (depth == 1.0) edge = vec4(0.5);
    if (d0 == 1.0) e0 = 0.5;
    if (d1 == 1.0) e1 = 0.5;
    if (d2 == 1.0) e2 = 0.5;
    if (d3 == 1.0) e3 = 0.5;
    
    mat4x3 c;
    c[0] = texelFetch(colortex0, ivec2(gl_FragCoord) + ivec2( 1, 0),0).rgb;
    c[1] = texelFetch(colortex0, ivec2(gl_FragCoord) + ivec2(-1, 0),0).rgb;
    c[2] = texelFetch(colortex0, ivec2(gl_FragCoord) + ivec2( 0, 1),0).rgb;
    c[3] = texelFetch(colortex0, ivec2(gl_FragCoord) + ivec2( 0,-1),0).rgb;
    
    mat4x2 e = mat4x2(
    clamp(0.5-edge.x,0.0,0.5), clamp(e0-0.5,0.0,0.5),
    clamp(0.5-edge.y,0.0,0.5), clamp(e1-0.5,0.0,0.5),
    clamp(0.5-edge.z,0.0,0.5), clamp(e2-0.5,0.0,0.5),
    clamp(0.5-edge.w,0.0,0.5), clamp(e3-0.5,0.0,0.5));

    vec4 w;
    w.x = abs(d0 - depth)<0.0001 ? max(e[0].x, e[0].y) : mix(e[0].x, e[0].y, d0 < depth);
    w.y = abs(d1 - depth)<0.0001 ? max(e[1].x, e[1].y) : mix(e[1].x, e[1].y, d1 < depth);
    w.z = abs(d2 - depth)<0.0001 ? max(e[2].x, e[2].y) : mix(e[2].x, e[2].y, d2 < depth);
    w.w = abs(d3 - depth)<0.0001 ? max(e[3].x, e[3].y) : mix(e[3].x, e[3].y, d3 < depth);
    
    
    float wsum = w.x+w.y+w.z+w.w;
    
    if (wsum > 1.0) {
        w /= wsum;
        wsum = 1.0;
    }
    
    color = (c*w) + color * (1.0 - wsum);
    #endif
    
    
    //color = texelFetch(colortex9, ivec2(gl_FragCoord), 0).baa;
}