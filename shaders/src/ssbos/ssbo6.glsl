layout(std430, binding = 6) buffer storageSSBO {
    uint histogram[1024];
    vec3 averageSkyInscattering;
    float Lum;
};