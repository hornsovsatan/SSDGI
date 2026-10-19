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

vec3 getLightMapContribution(vec3 D, float t, vec2 lightmap, sampler2D skytex) {
    const vec2 lightMapStrength = vec2(LM_INTENSITY * 0.2, 1.0);
    if (DIMENSION == DIM_END || DIMENSION == DIM_NETHER) lightmap.y = 1.0;
    
    D = mat3(gbufferModelViewInverse) * D;
    vec3 sun = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec2 uv = atmo_directionToEnvMapCoords(D, sun);
    vec3 skyColor =  textureLod(skytex, uv, 0).rgb;
    
    vec3 blockLight = vec3(0.996, 0.929, 0.745) * lightMapStrength.x * lightmap.x * mix(0.5, saturate(1.0 - t * 0.1), lightmap.x);
    vec3 skyLight = skyColor * lightMapStrength.y * lightmap.y * saturate(0.2 + t * 0.4);
    
    return blockLight + skyLight;
}