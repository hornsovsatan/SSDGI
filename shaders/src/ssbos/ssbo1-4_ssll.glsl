layout(std430, binding = 1) buffer ssllBuffer0 {
    uint ssllCounters[5];
};

layout(std430, binding = 2) buffer ssllBuffer1 {
    uint ssllBitmasks[];
};

layout(std430, binding = 3) buffer ssllBuffer2 {
    uint ssllSums[];
};

layout(std430, binding = 4) buffer ssllBuffer3 {
    uint ssllTileSums[1024];
};