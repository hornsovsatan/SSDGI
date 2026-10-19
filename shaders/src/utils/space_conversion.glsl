/*
 * All Rights Reserved
 * 
 * Copyright (c) 2024 lipesto
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


//VTXS SPACE CONVERSION LIB
//dependencies
/*-------------------------------------
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

*///-----------------------------------

//DEPRECATED

vec3 worldToViewSpace(vec3 position) {
    return mat3(gbufferModelView) * position;
}

vec3 viewToWorldSpace(vec3 position) {
    return mat3(gbufferModelViewInverse) * position;
}

vec3 worldToViewSpaceF(vec3 position) {
    return mat4x3(gbufferModelView) * vec4(position, 1.0);
}

vec3 viewToWorldSpaceF(vec3 position) {
    return mat4x3(gbufferModelViewInverse) * vec4(position, 1);
}

vec3 viewToScreenSpace(vec3 position) {
    vec4 p =  gbufferProjection * vec4(position,1.0);
    return p.xyz/p.w;
}

vec3 screenToViewSpace(vec3 position) {
    vec4 p = gbufferProjectionInverse * vec4(position, 1.0);
    return p.xyz/p.w;
}

vec3 worldToScreenSpace(vec3 position) {
    return viewToScreenSpace(worldToViewSpace(position));
}

vec3 screenToWorldSpace(vec3 position) {
    return viewToWorldSpace(screenToViewSpace(position));
}

vec3 worldToScreenSpaceF(vec3 position) {
    return viewToScreenSpace(worldToViewSpaceF(position));
}

vec3 screenToWorldSpaceF(vec3 position) {
    return viewToWorldSpaceF(screenToViewSpace(position));
}


