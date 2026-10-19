struct ssll_lightDataPack{
    uint uv;
    uint LOSD;
    uint normal;
};

layout(std430, binding = 5) buffer ssllBuffer4 {
    ssll_lightDataPack ssllLights[];
};