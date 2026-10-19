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

uniform int currentRenderedItemId;
uniform int entityId;
uniform int renderStage;

in vec4 at_tangent;

out vertex {
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
    blockID = entityId != 65535 ? entityId | 0x10000 : currentRenderedItemId;
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
uniform vec4 entityColor;

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
    
    if (textureColor.a < alphaTestRef) discard;
    if ((blockID & 0xFFFF) == 400 && vertexColor.a < 0.9) discard;
    
    
    
    mat3 TBN = unpackTBN(tbnPack, normalZ);
    vec2 vanillaLight = getVanillaLight(lightmapCoordinates);
    vec3 hcEmission = blockID > 0xFFFF ? entityIDEmission[(blockID & 0xFFFF) > 100 ? 0 : (blockID & 0xFFFF)] : blockIDEmission[(blockID > 100 ? 0 : blockID)];
    bool vanillaEmissive = lightmapCoordinates.x > 1.115;
    
    if (vanillaEmissive) vanillaLight.x = 0.0;
    if ((blockID & 0xFFFF) == 400 && vertexColor.a > 0.9) hcEmission = vec3(0.001);
    
    albedo.rgb  = getAlbedo(textureColor, vertexColor.rgb);
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
    albedo.a    = packVanillaLight(vanillaLight);
    geometry    = packGeometryProperties(getNormal(textureNormal, TBN), TBN[2], textureSpecular.xy);
    emission    = getEmission(albedo.rgb, textureSpecular, hcEmission, vanillaEmissive);
    primitive   = getZwidth(gl_FragCoord.z);
    primitive  |= getSSS(textureSpecular);
    #if AA > 0
    primitive |= GBAA(quadCoordinates, atlasCoordinates * textureSize(gtexture, 0));
    #endif
    
}

#endif