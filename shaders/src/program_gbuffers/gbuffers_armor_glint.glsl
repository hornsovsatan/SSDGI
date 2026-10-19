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

uniform int renderStage;

out vertex{
    vec2 atlasCoordinates;
    vec3 vertexColor;
};

void main() {
    bool isHand = renderStage == MC_RENDER_STAGE_HAND_SOLID;
    
    gl_Position = gl_ProjectionMatrix * ((gl_ModelViewMatrix * gl_Vertex) * vec4(vec3(isHand ? 0.3 : 1.0), 1.0));
    if (isHand) gl_Position.z /= MC_HAND_DEPTH;
    atlasCoordinates = getAtlasCoordinates();
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
    vec3 vertexColor;
};

/* RENDERTARGETS: 0,2 */

layout(location = 0) out vec4  albedo;
layout(location = 1) out vec3  emission;

void main() {
    vec4 textureColor = texture(gtexture, atlasCoordinates);
    
    albedo = textureColor * 0.4;
    albedo.a = 0.0;
    emission = textureColor.rgb * textureColor.rgb * 2.0;
}

#endif