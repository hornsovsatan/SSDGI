#define SMOOTH_REFLECTION_THRESHOLD 0.15
#define Z_WIDTH_SCALE 64

#define DIM_OVERWORLD 0
#define DIM_NETHER 1
#define DIM_END 2

#define M_PI 3.1415927


float saturate(float x) {return clamp(x, 0.0, 1.0);}
vec2  saturate(vec2  x) {return clamp(x, 0.0, 1.0);}
vec3  saturate(vec3  x) {return clamp(x, 0.0, 1.0);}
vec4  saturate(vec4  x) {return clamp(x, 0.0, 1.0);}

float luminance(vec3 color) {return dot(color, vec3(0.2126, 0.7152, 0.0722));}

vec3 projectPoint(vec3 point, mat4 matrix) {
    vec4 p = matrix * vec4(point, 1.0);
    return p.xyz / p.w;
}
vec3 projectPoint(vec4 point, mat4 matrix) {
    vec4 p = matrix * point;
    return p.xyz / p.w;
}
float projectZ(float z, mat4 matrix) {
    return (matrix[2].z * z + matrix[3].z) / 
           (matrix[2].w * z + matrix[3].w);
}
