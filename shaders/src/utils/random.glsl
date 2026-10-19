#ifndef RANDOM
#define RANDOM

//Tiny Encryption Algorithm (TEA) by David Wheeler and Roger Needham
uint tea(uvec2 u)
{
  uint s0 = 0;
  for(uint i = 0; i < 6; i++) {
    s0 += 0x9e3779b9;
    u += ((u.yx << 4) + uvec2(0xa341316c, 0xad90777d) ^ (u.yx + s0) ^ ((u.yx >> 5) + uvec2(0xc8013ea4,0x7e95761e)));
  }
  return u.x;
}

// Linear Congruential Generator from Numerical Recipes
uint lcg(inout uint seed)
{
    seed = seed * 1664525u + 1013904223u;
    return seed & 0x00FFFFFF;
}

float rnd(inout uint seed) {
    return (float(lcg(seed)) / float(0x01000000));
}

vec2 r2(float idx)
{    
    return fract(idx * vec2(0.7548776662467, 0.569840290998));
}

uint hash33(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return floatBitsToUint((p.x + p.y) * p.z);
}

uint generateSeed(vec3 v) {
    return hash33(v);
}

#endif