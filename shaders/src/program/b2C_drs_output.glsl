/*
 * All Rights Reserved
 * 
 * Copyright (c) 2025 lipesto
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

#define OVERWORLD_EXCLUSIVE

#include "/properties/shadow_settings.glsl"
#include "/src/ssbos/ssbo0_drs.glsl"

const ivec3 workGroups = ivec3(1, 1, 1);
layout (local_size_x = 1) in;


void main()
{   
    vec2 map0 = blCorner / (shadowMapResolution / 2.0);
    vec2 map1 = trCorner / (shadowMapResolution / 2.0);
    
    vec2 scale = 2.0 / (trCorner - blCorner) * (shadowMapResolution / 2.0);
    vec2 offset = -(map1 + map0) / (map1 - map0);
    
    vec2 newScale = min(scale, 3.0);
    newScale = floor(newScale * 8) / 8;
    
    offset *= newScale / scale;
    
    offset = round(offset * (shadowMapResolution / 4.0)) / (shadowMapResolution / 4.0);
    
    drs_scale  = newScale;
    drs_offset = offset;
    
    //Force off
    // drs_scale = vec2(1.0);
    // drs_offset = vec2(0.0);
    
}