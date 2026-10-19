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

vec3 blurPass(ivec2 fragCoord, ivec2 readOffset, int radius, sampler2D hiZtex, sampler2D gpbColor2t, usampler2D colortex3) {
    
    float z0 = texelFetch(hiZtex, fragCoord, 0).r;
    vec3 color = texelFetch(gpbColor2t, readOffset + fragCoord, 0).rgb;
    float zwidth = float(texelFetch(colortex3, fragCoord * HIZ_PIXEL_SIZE + (HIZ_PIXEL_SIZE/2), 0).r >> 16) / (float(0xFFFF) * Z_WIDTH_SCALE) * HIZ_PIXEL_SIZE + 0.0005;
    
    
    
    float wsum = 1.0;
    for (int x = -radius; x<=radius; x+=radius) {
    for (int y = -radius; y<=radius; y+=radius) {
    if (x==0 && y==0) continue;
        ivec2 uv = clamp(fragCoord + ivec2(x,y), ivec2(0), ivec2(resolution / 3.0));
        
        vec3 c1 = texelFetch(gpbColor2t, uv + readOffset, 0).rgb;
        float z1 = texelFetch(hiZtex, uv, 0).r;
        
        float k = (x==0 ? 1.0 : 0.3) * (y==0 ? 1.0 : 0.3);
        float w = step(abs(z1 - z0), (abs(x) + abs(y)) * zwidth) * k;
        color += c1.rgb * w;
        wsum += w;
    }}
    color /= wsum;
    
    return color;
}

ivec2 tileMapping(int i) {
    i = clamp(i, 0, 5);
    return ivec2(i % 3, i / 3) * ivec2(resolution / HIZ_PIXEL_SIZE);
}

float viewToScreenScale(float z) {
    return gbufferProjectionInverse[0][0] * resolution.x / -z * 0.25;
}

float getRadius(vec3 hitPosition, float t, float roughness) {
    float zScale = viewToScreenScale(hitPosition.z);
    float angle = pow(roughness, 1.0 / 1.8) * 0.3;
    angle = min(angle, 0.15);
    if (roughness > SMOOTH_REFLECTION_THRESHOLD) angle *= 0.25;
    float radius = t * zScale * angle;
    return radius;
}

vec2 uvTransform(vec2 uv, int lod) {
    return (uv / HIZ_PIXEL_SIZE + tileMapping(lod));
}

vec3 getFilteredEmissionTrilinear(vec3 hitPosition, float t, float roughness, vec2 uv, sampler2D fullResTex, sampler2D mipTex) {
    float radius = getRadius(hitPosition, t, roughness);
    float lod = clamp(log2(radius / HIZ_PIXEL_SIZE), 0, 5);
    
    vec3 c0 =  radius < HIZ_PIXEL_SIZE * 2 ? textureLod(fullResTex, uv * resolutionInv, 0).rgb : textureLod(mipTex, uvTransform(uv, int(floor(lod))) * resolutionInv, 0).rgb;
    vec3 c1 =  textureLod(mipTex, uvTransform(uv, int(ceil(lod))) * resolutionInv, 0).rgb;
    
    return mix(c0, c1, fract(lod));
}

vec3 getFilteredEmission(vec3 hitPosition, float t, float roughness, vec2 uv, sampler2D fullResTex, sampler2D mipTex) {
    float radius = getRadius(hitPosition, t, roughness);
    float lod = clamp(log2(radius / HIZ_PIXEL_SIZE), 0, 5);
    
    vec3 c0 =  radius < HIZ_PIXEL_SIZE * 2 ? textureLod(fullResTex, uv * resolutionInv, 0).rgb :
    textureLod(mipTex, uvTransform(uv, int(round(lod))) * resolutionInv, 0).rgb;
    
    return c0;
}