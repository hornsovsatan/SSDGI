 /*
 * All Rights Reserved
 * 
 * Copyright (c) 2024-2025 lipesto
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

#include "/src/gbuffers/vertex.glsl"

in vec4 at_tangent;

out vertex{
    vec2 atlasCoordinates;
    vec2 lightmapCoordinates;
    vec3 vertexColor;
    flat mat3 TBN;
};

void main() {
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    gl_Position.z /= MC_HAND_DEPTH;
    atlasCoordinates = getAtlasCoordinates();
    lightmapCoordinates = getLightmapCoordinates();
    vertexColor = gl_Color.rgb;
    TBN = buildTBN(gl_Normal, at_tangent);
}

#endif
#ifdef FRAGMENT

#include "/properties/shader_settings.glsl"
#include "/src/gbuffers/fragment.glsl"

uniform sampler2D gtexture;
uniform sampler2D specular;
uniform sampler2D normals;

uniform float alphaTestRef = 0.1;

in vertex {
    vec2 atlasCoordinates;
    vec2 lightmapCoordinates;
    vec3 vertexColor;
    flat mat3 TBN;
};


/* DRAWBUFFERS:01 */
layout(location = 0) out vec4 color;
layout(location = 1) out uvec2 gout;

void main() {
    vec4 textureColor = texture(gtexture, atlasCoordinates);
    vec4 textureSpecular = texture(specular, atlasCoordinates, -1.0);
    vec4 textureNormal = texture(normals, atlasCoordinates);
    
    vec3 normal;
        normal.xy = textureNormal.xy * 2.0 - 1.0;
        normal.z = sqrt(1.0 - clamp(dot(normal.xy, normal.xy), 0.0, 1.0));
        normal = normalize(TBN * normal);
        
        color.rgb = mix(pow(textureColor.rgb, vec3(2.2)),  vec3(1), 0.1 * (1.0 - textureColor.a));
        float cl = dot(color.rgb, vec3(1.0/3.0));
        color.rgb *= min(1.0, 0.7 / cl);
        color.a = 0.0;
    
    gout.x = packSnorm2x16(octaEncode(normal));
    gout.y = packUnorm2x16(lightmapCoordinates);
}

#endif