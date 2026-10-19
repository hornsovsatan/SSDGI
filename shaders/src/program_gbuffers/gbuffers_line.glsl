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

const float LINE_WIDTH  = 2.5;
const float VIEW_SHRINK = 1.0 - (1.0 / 256.0);
const vec4 VIEW_SCALE   = vec4(VIEW_SHRINK, VIEW_SHRINK, VIEW_SHRINK, 1);

uniform vec2 resolution;
uniform vec2 resolutionInv;

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;
uniform vec3 chunkOffset;

in vec3 vaPosition;
in vec3 vaNormal;
in vec4 vaColor;


out vertex {
    vec4 vertexColor;
};

void main() {
	vec4 vertex = vec4(vaPosition + chunkOffset, 1.0);
	vec4 linePosStart = projectionMatrix * (VIEW_SCALE * (modelViewMatrix * vertex));
	vec4 linePosEnd   = projectionMatrix * (VIEW_SCALE * (modelViewMatrix * vec4(vertex.xyz + vaNormal, 1.0)));

	vec3 ndc1 = linePosStart.xyz / linePosStart.w;
	vec3 ndc2 = linePosEnd.xyz   / linePosEnd.w;

	vec2 lineScreenDirection = normalize((ndc2.xy - ndc1.xy) * resolution);
	vec2 lineOffset = vec2(-lineScreenDirection.y, lineScreenDirection.x) * LINE_WIDTH * resolutionInv;

	if (bool(gl_VertexID & 1)) lineOffset = -lineOffset;
	gl_Position = vec4((ndc1 + vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
	vertexColor = vaColor;
} 

#endif
#ifdef FRAGMENT

#include "/properties/shader_settings.glsl"
#include "/src/gbuffers/fragment.glsl"

uniform sampler2D gtexture;
uniform sampler2D specular;
uniform sampler2D normals;
uniform sampler2D depthtex0;

uniform float alphaTestRef = 0.1;

in vertex {
    vec4 vertexColor;
};

layout (rgba8) uniform image2D colorimg0;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 albedo;
layout(location = 1) out vec4 albedo2;

void main() {
    albedo = vertexColor;
	albedo.a = 1.0 - (1.0 - albedo.a) * 0.7;
	//imageStore(colorimg0, ivec2(gl_FragCoord), vec4(0));
	albedo2 = albedo;
	albedo2.a = 1.0;
	gl_FragDepth = mix(texelFetch(depthtex0, ivec2(gl_FragCoord), 0).r, gl_FragCoord.z, 0.003);
}

#endif