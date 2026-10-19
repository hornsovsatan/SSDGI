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
in vec2 mc_Entity;

out vertex{
    vec2 atlasCoordinates;
    vec2 lightmapCoordinates;
    vec2 quadCoordinates;
    vec4 vertexColor;
    flat int blockID;
    flat float normalZ;
    flat uvec4 tbnPack;
};

void main() {
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    atlasCoordinates = getAtlasCoordinates();
	lightmapCoordinates = getLightmapCoordinates();
    quadCoordinates = getQuadCoordinates();
    vertexColor = gl_Color;
    blockID = max(int(mc_Entity.x), 0);
    mat3 TBN = buildTBN(gl_Normal, at_tangent);
    normalZ = TBN[2].z;
    tbnPack = packTBN(TBN);
}

#endif
#ifdef FRAGMENT

#include "/properties/shader_settings.glsl"
#include "/properties/id_emission.glsl"
#include "/src/gbuffers/fragment.glsl"

uniform sampler2D gtexture;
uniform sampler2D specular;
uniform sampler2D normals;

uniform float alphaTestRef = 0.1;
uniform ivec2 atlasSize;

in vertex {
    vec2 atlasCoordinates;
    vec2 lightmapCoordinates;
    vec2 quadCoordinates;
    vec4 vertexColor;
    flat int blockID;
    flat float normalZ;
    flat uvec4 tbnPack;
};



/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4  albedo;
layout(location = 1) out uvec2 geometry;
layout(location = 2) out vec3  emission;
layout(location = 3) out uint primitive;

void main() {
    vec4 textureColor = texture(gtexture, atlasCoordinates);
    vec4 textureSpecular = texture(specular, atlasCoordinates, -1.0);
    vec4 textureNormal = texture(normals, atlasCoordinates);
    
    
    mat3 TBN = unpackTBN(tbnPack, normalZ);
    float ao = getAO(vertexColor.a);
    vec2 vanillaLight = getVanillaLight(lightmapCoordinates, ao);
    
    albedo.rgb  = getAlbedo(textureColor, vertexColor.rgb);
    albedo.a    = packVanillaLight(vanillaLight);
    geometry    = packGeometryProperties(getNormal(textureNormal, TBN), TBN[2], textureSpecular.xy);
    emission    = getEmission(albedo.rgb, textureSpecular, blockIDEmission[blockID > 100 ? 0 : blockID]);
    primitive   = getZwidth(gl_FragCoord.z);
    primitive  |= getSSS(blockID == 300 ? 1.0 : textureSpecular.b);
    #if AA > 0
    primitive  |= GBAA(quadCoordinates, atlasCoordinates * atlasSize);
    #endif
}

#endif

//if (textureColor.a < alphaTestRef) discard;