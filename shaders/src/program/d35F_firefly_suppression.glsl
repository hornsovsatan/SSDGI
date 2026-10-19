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

#include "/src/common.glsl"
#include "/src/uniforms.glsl"

/* RENDERTARGETS: 4,5 */
out vec4 diffuse;
out vec4 specular;

void main() {
    diffuse = texelFetch(colortex4, ivec2(gl_FragCoord), 0);
    specular = texelFetch(colortex5, ivec2(gl_FragCoord), 0);
    
    vec3 dMax = diffuse.rgb;
    vec3 dMin = diffuse.rgb;
    vec3 sMax = specular.rgb;
    vec3 sMin = specular.rgb;

    
    float dlmax = 0.0;
    float dlmin = 1e20;
    float slmax = 0.0;
    float slmin = 1e20;
    
    for (int x = -1; x<=1; x++) {
    for (int y = -1; y<=1; y++) {
        if (x==0 && y==0) continue;
        vec3 d1 = texelFetch(colortex4, ivec2(gl_FragCoord) + ivec2(x, y), 0).rgb;
        vec3 s1 = texelFetch(colortex5, ivec2(gl_FragCoord) + ivec2(x, y), 0).rgb;
        
        float dl = dot(d1, vec3(1));
        float sl = dot(s1, vec3(1));
        
        if (dl >= dlmax) {dlmax = dl; dMax = d1;}
        if (dl <= dlmin) {dlmin = dl; dMin = d1;}
        if (sl >= slmax) {slmax = sl; sMax = s1;}
        if (sl <= slmin) {slmin = sl; sMin = s1;}
    }}
    
    float dl = dot(diffuse.rgb, vec3(1));
    float sl = dot(specular.rgb, vec3(1));
    
    if (dl < dlmin) diffuse.rgb  = dMin;
    if (dl > dlmax) diffuse.rgb  = dMax;
    if (sl < slmin) specular.rgb = sMin;
    if (sl > slmax) specular.rgb = sMax;
    
}