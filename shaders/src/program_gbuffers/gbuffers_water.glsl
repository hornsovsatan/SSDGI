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

uniform float frameTimeCounter;
uniform vec3 cameraPosition;

float waveHeight(vec2 position, vec2 direction, float scale, float timeScale) {
    float speed = sqrt(9.8 * 2.0 * M_PI * scale);
    float x = (dot(position, direction) + frameTimeCounter * timeScale) * scale * 2.0 * M_PI * speed;
    return exp(sin(x) - 1.0) - 0.5;
}

in vec4 at_tangent;
in vec2 mc_Entity;

out vertex{
    vec2 atlasCoordinates;
    vec2 lightmapCoordinates;
    vec3 vertexColor;
    flat int blockID;
    flat mat3 TBN;
};

void main() {
    blockID = int(mc_Entity);
    vec3 pos = gl_Vertex.xyz;
	
	if (blockID==100) {
		vec2 wavePos = pos.xz + cameraPosition.xz;
		float h = 0;
		h += waveHeight(wavePos, vec2( 0.327, 0.945) , 0.07, 1.0);
		h += waveHeight(wavePos, vec2(-0.811, -0.585), 0.09, 1.0);
		h += waveHeight(wavePos, vec2( 0.998, -0.063), 0.06, 1.0);
		h += waveHeight(wavePos, vec2(-0.456, 0.890) , 0.11, 1.0);
		h += waveHeight(wavePos, vec2( 0.032, -0.999), 0.10, 1.0);
		
		pos.y += h * 0.04 * fract(pos.y + cameraPosition.y);
	}
    
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * vec4(pos, 1));
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
    flat int blockID;
    flat mat3 TBN;
};


/* DRAWBUFFERS:01 */
layout(location = 0) out vec4 color;
layout(location = 1) out uvec2 gout;

void main() {
    vec4 textureColor = texture(gtexture, atlasCoordinates);
    vec4 textureSpecular = texture(specular, atlasCoordinates, -1.0);
    vec4 textureNormal = texture(normals, atlasCoordinates);
    
    bool isWater = blockID == 100;
    
    vec3 normal;
    if (isWater) {
        normal = TBN[2];
        color.rgb = mix(vec3(1), pow(textureColor.rgb * vertexColor, vec3(2.2)),  0.5 * textureColor.a);
        color.a = 128.0 / 255.0;
    } else {
        normal.xy = textureNormal.xy * 2.0 - 1.0;
        normal.z = sqrt(1.0 - clamp(dot(normal.xy, normal.xy), 0.0, 1.0));
        normal = normalize(TBN * normal);
        
        color.rgb = mix(pow(textureColor.rgb * vertexColor, vec3(2.2)),  vec3(1), 0.1 * (1.0 - textureColor.a));
        float cl = dot(color.rgb, vec3(1.0/3.0));
        color.rgb *= min(1.0, 0.7 / cl);
        color.a = 0.0;
    }
    
    gout.x = packSnorm2x16(octaEncode(normal));
    gout.y = packUnorm2x16(lightmapCoordinates);
}

#endif