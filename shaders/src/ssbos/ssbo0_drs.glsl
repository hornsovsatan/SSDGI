layout(std430, binding = 0) buffer drsBuffer {
    ivec2 trCorner;
    ivec2 blCorner;
    
    vec2 drs_scale;
    vec2 drs_offset;
};