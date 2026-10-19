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
 
uint getGroupIndex(uvec2 groupID, uvec3 numGroups) {
    return groupID.x + groupID.y * numGroups.x;
}

uint getGroupIndex(uvec3 groupID, uvec3 numGroups) {
    return groupID.x + (groupID.y + groupID.z * numGroups.y) * numGroups.x;
}


//getGlobalInvocationIndex(gl_LocalInvocationIndex, gl_WorkGroupID.xy, gl_NumWorkGroups, gl_WorkGroupSize);
uint getGlobalInvocationIndex(uint localIndex, uvec2 groupID, uvec3 numGroups, uvec3 groupSize) {
    return localIndex + groupSize.x * groupSize.y * getGroupIndex(groupID, numGroups);
}

//getGlobalInvocationIndex(gl_LocalInvocationIndex, gl_WorkGroupID, gl_NumWorkGroups, gl_WorkGroupSize);
uint getGlobalInvocationIndex(uint localIndex, uvec3 groupID, uvec3 numGroups, uvec3 groupSize) {
    return localIndex + groupSize.x * groupSize.y * groupSize.z * getGroupIndex(groupID, numGroups);
}


uint getGlobalInvocationIndex(uint localIndex, uint groupIndex, uvec2 groupSize) {
    return localIndex + groupSize.x * groupSize.y * groupIndex;
}

uint getGlobalInvocationIndex(uint localIndex, uint groupIndex, uvec3 groupSize) {
    return localIndex + groupSize.x * groupSize.y * groupSize.z * groupIndex;
}


ivec2 idToCoord(uint id, ivec2 resolution) {
    return ivec2(id % resolution.x, id / resolution.x);
}

ivec2 idToCoord(uint id, vec2 resolution) {
    return ivec2(id % int(resolution), id / int(resolution));
}

bool inBoundsTR(ivec2 uv, ivec2 bounds) {
    return all(lessThan(uv, bounds));
}

bool inBoundsTR(ivec2 uv, vec2 bounds) {
    return inBoundsTR(uv, ivec2(bounds));
}