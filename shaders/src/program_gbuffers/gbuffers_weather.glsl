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

#include "/src/common.glsl"
#include "/src/gbuffers/vertex.glsl"

mat4 skewY(vec2 v) {
    float o = -4.0;
    return mat4(1.0, 0.0, 0.0, 0.0,
                v.x, 1.0, v.y, 0.0,
                0.0, 0.0, 1.0, 0.0,
                o*v.x, 0.0, o*v.y, 1.0);
}
uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform int worldTime;

out vertex{
    vec2 atlasCoordinates;
    vec2 lightmapCoordinates;
    vec3 vertexColor;
};

void main() {
    vec2 r = textureLod(noisetex, vec2(worldTime * 0.0001, 0), 0).xy;
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * skewY(vec2(r * 2.0 - 1.0) * 0.15) * gl_Vertex);
    atlasCoordinates = getAtlasCoordinates();
    lightmapCoordinates = getLightmapCoordinates();
    vertexColor = gl_Color.rgb;
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
};


/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 color;

void main() {
    vec4 textureColor = texture(gtexture, atlasCoordinates);
    vec4 textureSpecular = texture(specular, atlasCoordinates, -1.0);
    vec4 textureNormal = texture(normals, atlasCoordinates);
    if (textureColor.a < alphaTestRef) discard;
    
    color.rgb = vec3(1.0);
    color.a = 1.0 / 255.0;
}

#endif