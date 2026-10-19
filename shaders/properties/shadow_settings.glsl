
#define SHADOW_QUALITY 1 //[0 1 2]
#define SHADOW_DISTANCE 1.000 //[0.375 0.500 0.750 1.000 1.250 1.500 2.000 2.500 3.000]
///                            3     4     6    8      10    12    16    20    24

#if SHADOW_QUALITY == 0
    const int shadowMapResolution = 1024;

    const float maxPenumbraSize = 0.2;
    const float minPenumbraSize = 0.045;
    const float minPenumbraHardening = 0.01;

    const int blockerSteps = 20;
    const int penumbraSteps = 6;
    
    const int shadowMapBaseLOD = 0;

#elif SHADOW_QUALITY == 2
    const int shadowMapResolution = 4096;

    const float maxPenumbraSize = 0.3;
    const float minPenumbraSize = 0.01;
    const float minPenumbraHardening = 0.002;

    const int blockerSteps = 35;
    const int penumbraSteps = 16;
    
    const int shadowMapBaseLOD = 2;
#else //DEFAULT
    const int shadowMapResolution = 2048;

    const float maxPenumbraSize = 0.25;
    const float minPenumbraSize = 0.025;
    const float minPenumbraHardening = 0.005;

    const int blockerSteps = 30;
    const int penumbraSteps = 10;
    
    const int shadowMapBaseLOD = 2;
#endif

const int shadowMapBaseResolution = shadowMapResolution >> shadowMapBaseLOD;

const float shadowDistance = 128.0;



const float shadowZScale = 0.25;
const float distortionFactor = 0.84;



const float shadowDistanceRenderMul = SHADOW_DISTANCE;
const float entityShadowDistanceMul = 0.2;

const bool shadowtex1Mipmap = true;