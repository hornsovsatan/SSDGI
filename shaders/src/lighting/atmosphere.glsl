const float seaLevel = -60.0;
const float earthRadius = 6360e2 * 2;
const float atmosphereRadius = 6380e2 * 2;
const float atmosphereWidth = atmosphereRadius - earthRadius;
const float scaleHeightR = 800;
const float scaleHeightM = 120;
const vec3 scatteringCoefficientsR = vec3(5e-5, 14e-5, 35e-5);
vec3 scatteringCoefficientsM = vec3(3.9e-5);
vec3 absorptionCoefficientsM = vec3(4.4e-5);

// const vec3 scatteringCoefficientsR = vec3(5.8e-5, 13.5e-5, 33.1e-5);
// const vec3 scatteringCoefficientsM = vec3(5.0e-2);
// const vec3 absorptionCoefficientsM = vec3(4.4e-3);


//mat2x3 extinctionCoefficients = mat2x3(scatteringCoefficientsR, scatteringCoefficientsM + absorptionCoefficientsM);
mat2x3 extinctionCoefficients;


const float sunAngularRadius = radians(0.625);
const float moonAngularRadius = radians(0.625);
const float sunSolidAngle = 2.0 * M_PI * (1.0 - cos(sunAngularRadius));
const float moonSolidAngle = 2.0 * M_PI * (1.0 - cos(moonAngularRadius));

const float sunIrradiance   = 25.0;
const float moonIrradiance  = sunIrradiance / 1361.0;
const float sunRadiance    = sunIrradiance / sunSolidAngle; // ~2675
const float moonRadiance   = moonIrradiance / moonSolidAngle;

void atmosphereDriver() {
    scatteringCoefficientsM = mix(vec3(4e-5, 10e-5, 30e-5)*1, vec3(3.0e-2), rainStrength);
    absorptionCoefficientsM = mix(vec3(4.4e-5), vec3(4.4e-3), rainStrength);
    
    extinctionCoefficients = mat2x3(scatteringCoefficientsR, scatteringCoefficientsM + absorptionCoefficientsM);
}

vec2 atmo_rayCircleIntersectionX(vec2 O, float r) {
    float disc = r * r - O.y * O.y;
    if (disc < 0.0) return vec2(-1.0);
    disc = sqrt(disc);
	return vec2(-O.x - disc, -O.x + disc);
}

vec2 atmo_raySphereIntersection(vec3 O, vec3 D, float r) {
    float a = dot(D, D);
    float b = 2.0 * dot(D, O);
    float c = dot(O, O) - r * r;
    float disc = b * b - 4.0 * a * c;
    if (disc < 0.0) return vec2(-1.0);
    disc = sqrt(disc);
	return vec2(-b - disc, -b + disc) / (2.0 * a);
}

vec3 atmo_computeAttenuation(vec2 uv) {
    float X = (uv.x * 2.0 - 1.0) * atmosphereRadius;
    float H = uv.y * (atmosphereRadius - earthRadius) + earthRadius;
    vec2 O = vec2(X, sqrt(H * H - X * X));
    
    const int steps = 32;
    float hitPlanet = atmo_rayCircleIntersectionX(O, earthRadius).y;
        if (hitPlanet < 0) {
            float hitAtmosphere = atmo_rayCircleIntersectionX(O, atmosphereRadius).y;
            float stepLength = hitAtmosphere / steps;
            vec2 opticalDepth = vec2(0);
            for (int j = 0; j<steps; j++) {
                vec2 P = O + vec2((j + 0.5) * stepLength, 0);
                float height = length(P) - earthRadius;
                vec2 density = exp(-height / vec2(scaleHeightR, scaleHeightM));
                vec2 opticalDepthStep = density * stepLength;
                opticalDepth += opticalDepthStep;
            }
            return exp(-(extinctionCoefficients * opticalDepth));
        }
    return vec3(0);
}

mat2x3 atmo_getAttenuation(vec3 P, vec3 sun, float height, sampler2D skyLUTtex) {
    float X = dot(P, sun) / atmosphereRadius * 0.5 + 0.5;
    float Y = height / atmosphereWidth;
    vec3 attenuationSun = textureLod(skyLUTtex, vec2(X,Y), 0).rgb;
    vec3 attenuationMoon = textureLod(skyLUTtex, vec2(1.0 - X,Y), 0).rgb;
    return mat2x3(attenuationSun, attenuationMoon);
}

vec3 atmo_anisotropicScattering(vec3 D, vec3 sun, mat2x3 contributionR, mat2x3 contributionM) {
    
    float mu = dot(D, sun);
    float phaseR = 3.0 / (16.0 * M_PI) * (1.0 + mu * mu); 
    
    //Rain phase function????????????
    // float g = 0.76; 
    // vec2 phaseM = 3.0 / (8.0 * M_PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / (2.0 + g * g) / pow(1.0 + g * g - 2.0 * g * vec2(mu, -mu), vec2(1.5)); 
    
    float g = 0.5;
    float a = 5.0;
    vec2 phaseM = (1.0 / (4.0 * M_PI)) * ((1.0 - g*g) / pow(1.0 + g*g - 2.0 * g * vec2(mu, -mu), vec2(1.5))) * ((1.0 + a * mu*mu) / (1.0 + a * (1.0 + 2.0 * g*g) / 3.0)); 
    
    vec3 sunContribution = (contributionR[0] * scatteringCoefficientsR * phaseR + contributionM[0] * scatteringCoefficientsM * phaseM.x) * sunIrradiance;
    vec3 moonContribution = (contributionR[1] * scatteringCoefficientsR * phaseR + contributionM[1] * scatteringCoefficientsM * phaseM.y) * moonIrradiance;
    return sunContribution + moonContribution;
}

vec3 atmo_getSegmentTransmittance(vec3 O, vec3 D, float segmentLength) {
    vec3 midP = O + D * 0.5 * segmentLength;
    
    float height = length(midP) - earthRadius;
    vec2 density = exp(-height / vec2(scaleHeightR, scaleHeightM));
    vec2 opticalDepth = segmentLength * density;
    
    return exp(-(extinctionCoefficients * opticalDepth));
}

vec3 atmo_getSegmentInscatteringShort(vec3 O, vec3 D, float segmentLength, vec3 sun, sampler2D skyLUTtex, out vec3 transmittance) {
    
    vec3 midP = O + D * 0.5 * segmentLength;
    
    float height = length(midP) - earthRadius;
    vec2 density = exp(-height / vec2(scaleHeightR, scaleHeightM));
    vec2 opticalDepth = segmentLength * density;
    
    mat2x3 attenuationLights = atmo_getAttenuation(midP, sun, height, skyLUTtex);
    vec3 attenuationEye = exp(-(extinctionCoefficients * opticalDepth));
    
    attenuationLights[0] *= attenuationEye;
    attenuationLights[1] *= attenuationEye;
    mat2x3 contributionR = attenuationLights * opticalDepth.x;
    mat2x3 contributionM = attenuationLights * opticalDepth.y;
    
    
    transmittance = exp(-(extinctionCoefficients * opticalDepth));
    return atmo_anisotropicScattering(D, sun, contributionR, contributionM);
}

vec3 atmo_getSegmentInscatteringEnvmap(vec3 O, vec3 D, float segmentLength, vec3 sun, sampler2D skyLUTtex, out vec3 transmittance) {
    
    vec2 opticalDepth = vec2(0);
    mat2x3 contributionR = mat2x3(0);
    mat2x3 contributionM = mat2x3(0);
    
    const int steps = 64;
    float stepLength = segmentLength / steps;
    for (int i = 0; i<steps; i++) {
        vec3 P = O + D * (i + 0.5) * stepLength;
        
        float height = length(P) - earthRadius;
        vec2 density = exp(-height / vec2(scaleHeightR, scaleHeightM));
        vec2 stepOpticalDepth = stepLength * density;
        opticalDepth += stepOpticalDepth;
        
        mat2x3 attenuationLights = atmo_getAttenuation(P, sun, height, skyLUTtex);
        vec3 attenuationEye = exp(-(extinctionCoefficients * opticalDepth));
        
        attenuationLights[0] *= attenuationEye;
        attenuationLights[1] *= attenuationEye;
        contributionR += attenuationLights * stepOpticalDepth.x;
        contributionM += attenuationLights * stepOpticalDepth.y;
    }
    
    transmittance = exp(-(extinctionCoefficients * opticalDepth));
    return atmo_anisotropicScattering(D, sun, contributionR, contributionM);
}
#if DIMENSION == DIM_OVERWORLD
vec2 atmo_dirToUv(vec3 dir) {
    float azimuth = atan(dir.x, dir.z);
    float alt = asin(dir.y) / (M_PI * 0.5);
    alt = sign(alt) * sqrt(abs(alt));
    return vec2(azimuth / (2.0 * M_PI) + 0.5, alt * 0.5 + 0.5);
}

vec2 atmo_directionToEnvMapCoords(vec3 D, vec3 sun) {
    vec2 sunX = normalize(sun.xz);
    D.xz = -(D.z * sunX + vec2(-1, 1) * sunX.yx * D.x);
    
    vec2 uv = atmo_dirToUv(D);
    uv.y *= 0.5 * 255.0 / 256.0;
    uv.x = abs(uv.x * 2.0 - 1.0);
    return uv;
}
#else
vec2 atmo_dirToUv(vec3 dir) {
    float azimuth = atan(dir.x, dir.z);
    float alt = asin(dir.y) / (M_PI * 0.5);
    return vec2(azimuth / (2.0 * M_PI) + 0.5, alt * 0.5 + 0.5);
}

vec2 atmo_directionToEnvMapCoords(vec3 D, vec3 sun) {
    vec2 uv = atmo_dirToUv(D);
    uv.y *= 0.5 * 255.0 / 256.0;
    return uv;
}
#endif

vec3 atmo_getLightColorAtHeight(float height, vec3 sun, bool isSunAbove, sampler2D skyLUTtex) {
    vec2 lutUv = vec2(sun.y * (height - seaLevel + earthRadius) / atmosphereRadius * 0.5 + 0.5, (height - seaLevel) / atmosphereWidth);
    if (!isSunAbove) lutUv.x = 1.0 - lutUv.x;
    vec3 sunAttenuation = textureLod(skyLUTtex, lutUv, 0).rgb;
    vec3 sunlightColor = vec3(isSunAbove ? sunIrradiance : moonIrradiance);
    sunlightColor *= sunAttenuation;
    return sunlightColor;
}

vec3 atmo_getSegmentInscatteringEND(vec3 O, vec3 D, float segmentLength, int steps, out vec3 transmittance) {
    vec3 lightPos = vec3(0,300,0);
    
    float dA = smoothstep(100.0, 500.0, distance(cameraPosition.xz, lightPos.xz));
    float dB = smoothstep(500.0, 1000.0, distance(cameraPosition.xz, lightPos.xz));
    
    float density = 0.7;
    float atmosphereGlow = 0.0002 * dA;
    float scatteringCoefficient = 0.01;
    float absorptionCoefficient = mix(0.02, 0.001, dB);
    float extinctionCoefficient = scatteringCoefficient + absorptionCoefficient;
    
    
    float opticalDepth = 0;
    float contribution = 0;
    
    for (int i = 0; i < steps; i++) {
        vec3 P = O + D * ((i+0.5) / steps) * segmentLength;
        
        float stepOpticalDepth = segmentLength / steps * density;
        opticalDepth += stepOpticalDepth;
        
        float lightDistance = distance(P, lightPos);
        float attenuationLight = exp(-extinctionCoefficient * lightDistance);
        float attenuationEye = exp(-(extinctionCoefficient * opticalDepth));
        
        float segmentContribution = attenuationLight + atmosphereGlow;
        contribution += attenuationEye * segmentContribution * stepOpticalDepth;
    }
    
    transmittance = vec3(exp(-(extinctionCoefficient * opticalDepth)));
    return 10 * vec3(0.349, 0.184, 0.435) * contribution * scatteringCoefficient;
}


vec3 atmo_getSegmentInscatteringNETHER(vec3 O, vec3 D, float segmentLength, int steps, out vec3 transmittance) {
    
    float density = 0.2;
    float atmosphereGlow = 0.005;
    float scatteringCoefficient = 0.02;
    float absorptionCoefficient = 0.00;
    float extinctionCoefficient = scatteringCoefficient + absorptionCoefficient;
    
    bool belowCeiling = O.y < 128;
    
    vec2 height = vec2(0,128);
    if (D.y < 0.0) height = height.yx;
    vec2 planeDistance = height - cameraPosition.y;
    vec2 hit = planeDistance / D.y;
    
    if (belowCeiling)
        segmentLength = min(segmentLength, hit.y);
    
    float opticalDepth = 0;
    vec2 contribution = vec2(0);
    
    for (int i = 0; i < steps; i++) {
        vec3 P = O + D * ((i+0.5) / steps) * segmentLength;
        
        float stepOpticalDepth = segmentLength / steps * density;
        opticalDepth += stepOpticalDepth;
        
        float lightDistance = distance(P.y, 32);
        float attenuationLight = exp(-extinctionCoefficient * lightDistance);
        float attenuationEye = exp(-(extinctionCoefficient * opticalDepth));
        
        vec2 segmentContribution = vec2(attenuationLight, atmosphereGlow);
        contribution += attenuationEye * segmentContribution * stepOpticalDepth;
    }
    
    vec3 inscattering = contribution.x * pow(vec3(1.000, 0.624, 0.102), vec3(2.2)) * 0.0002 * float(belowCeiling) + contribution.y * pow(fogColor, vec3(2.2));
    transmittance = vec3(exp(-(extinctionCoefficient * opticalDepth)));
    return inscattering;
}


vec3 getGodrayColor(vec3 O, vec3 D, float segmentLength, vec3 sun, sampler2D skyLUTtex) {
    vec3 midP = O + D * 0.5 * segmentLength;
    
    float height = length(midP) - earthRadius;
    vec2 density = exp(-height / vec2(scaleHeightR, scaleHeightM));
    vec2 opticalDepth = segmentLength * density;
    
    mat2x3 attenuationLights = atmo_getAttenuation(midP, sun, height, skyLUTtex);
    mat2x3 contributionR = attenuationLights * opticalDepth.x;
    mat2x3 contributionM = attenuationLights * opticalDepth.y;
    
    vec3 atmoScattering = atmo_anisotropicScattering(D, sun, contributionR, contributionM);
    
    float mu = dot(D, sun);
    float g = 0.7;
    float phase = 3.0 / (8.0 * M_PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / (2.0 + g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5); 
    
    float timeFac = abs(0.25 - shadowAngle);
    vec3 color = attenuationLights[0] * attenuationLights[0] * segmentLength * phase * 0.05 * (timeFac * timeFac * 4.0 + 0.5) + atmoScattering;
    return color;
    
}

const vec3 waterAbsorptionCoefficients = vec3(0.09, 0.034, 0.034);
const vec3 waterScatteringCoefficients = vec3(0.01, 0.027, 0.027);
const vec3 waterExtinctionCoefficients = waterAbsorptionCoefficients + waterScatteringCoefficients;

vec3 getWaterFogColor(vec3 O, vec3 D, float segmentLength, vec3 sun, ivec2 fragCoord, out vec3 transmittance) {    
    float marchedSegmentLength = min(segmentLength, 50);
    
    float mu = dot(D, sun);
    float g = 0.85;
    float phaseF = 3.0 / (8.0 * M_PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / (2.0 + g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5); 
    g = -0.2;
    float phaseB = 3.0 / (8.0 * M_PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / (2.0 + g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5); 
    
    transmittance = exp(-segmentLength * waterExtinctionCoefficients);
    return marchedSegmentLength * mix(phaseB, phaseF, 0.8) * waterScatteringCoefficients * vec3(sunAngle < 0.5 ? sunIrradiance : moonIrradiance) * 0.1;
}

#ifdef ATMOSPHERE_SHADOWMAPPING
float sampleShadowMapTest(vec3 positionAligned) {
    vec3 position = transformShadowCoord(positionAligned);
    if (position.xy != saturate(position.xy)) return 1.0;
    return step(position.z, texelFetch(shadowtex1, ivec2(shadowMapBaseResolution * saturate(position.xy)), shadowMapBaseLOD).r * 2.0 - 1.0);
}

vec2 sampleShadowMapTestOq(vec3 positionAligned) {
    vec3 position = transformShadowCoord(positionAligned);
    vec2 shadow;
    shadow.x = step(position.z, texelFetch(shadowtex1, ivec2(shadowMapResolution * saturate(position.xy)), 0).r * 2.0 - 1.0);
    shadow.y = ((texelFetch(shadowtex0, ivec2(shadowMapResolution * saturate(position.xy)), 0).r * 2.0) * 2.0 - 1.0) / shadowSpaceScale.z;
    return shadow;
}

vec3 addGodrays(vec3 O, vec3 D, float segmentLength, vec3 sun, sampler2D skyLUTtex, bool isSky, ivec2 fragCoord, bool waterMedium) {
    vec3 midP = O + D * 0.5 * segmentLength;
    
    float height = length(midP) - earthRadius;
    vec2 density = exp(-height / vec2(scaleHeightR, scaleHeightM));
    vec2 opticalDepth = segmentLength * density;
    
    mat2x3 attenuationLights = atmo_getAttenuation(midP, sun, height, skyLUTtex);
    mat2x3 contributionR = attenuationLights * opticalDepth.x;
    mat2x3 contributionM = attenuationLights * opticalDepth.y;
    
    vec3 atmoScattering = atmo_anisotropicScattering(D, sun, contributionR, contributionM);
    
    O = vec3(0) + gbufferModelViewInverse[3].xyz;
    
    
    
    vec3 wO = worldToShadowAlignedSpace(O);
    vec3 wF = worldToShadowAlignedSpace(O + D * segmentLength);
    wF.z -= 0.1;
    
    float rand = blueNoiseScalar(ivec3(fragCoord, 0&3));
    
    int steps = 8;
    
    float vol = 0.0;
    for (int i = 0; i<steps; i++) {
        float t = (i + rand) / steps;
        vec3 wP = mix(wO, wF, t);
        
        float v = sampleShadowMapTest(wP);
        if (isSky) v = 1.0;
        
        float x = t * segmentLength / 50.0;
        float density = exp(-x);
        
        vol += v * density;
    }
    vol /= steps;
    
    float mu = dot(D, sun);
    float g = 0.7;
    float phase = 3.0 / (8.0 * M_PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / (2.0 + g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5); 
    
    float timeFac = abs(0.25 - shadowAngle);
    vec3 color = attenuationLights[0] * attenuationLights[0] * segmentLength * phase * 0.05 * (timeFac * timeFac * 4.0 + 0.5) + atmoScattering;
    //vec3 color = atmoScattering;
    
    return vol * color;
    
}
vec3 getWaterFog(vec3 O, vec3 D, float segmentLength, vec3 sun, ivec2 fragCoord, out vec3 transmittance) {
    float marchedSegmentLength = min(segmentLength, 50);
    O = vec3(0) + gbufferModelViewInverse[3].xyz;
    vec3 wO = worldToShadowAlignedSpace(O);
    vec3 wF = worldToShadowAlignedSpace(O + D * marchedSegmentLength);
    wF.z -= 0.1;
    
    float rand = blueNoiseScalar(ivec3(fragCoord, frameCounter&3));
    
    vec3 vol = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i<10; i++) {
        float t = (i + rand) / 10.0;
        vec3 wP = mix(wO, wF, t);
        
        vec2 shadow = sampleShadowMapTestOq(wP);
        
        float x = t * marchedSegmentLength;
        vec3 tr = exp(-x * waterExtinctionCoefficients);
        
        vec3 lightAttenuation = exp(-max(0.0, -wP.z + shadow.y) * waterExtinctionCoefficients);
        
        vol += shadow.x * tr * lightAttenuation;
    }
    vol /= 10;
    vol *= vec3(1,1,0.8);
    
    float mu = dot(D, sun);
    float g = 0.85;
    float phaseF = 3.0 / (8.0 * M_PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / (2.0 + g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5); 
    g = -0.2;
    float phaseB = 3.0 / (8.0 * M_PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / (2.0 + g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5); 
    
    transmittance = exp(-segmentLength * waterExtinctionCoefficients);
    return vol * marchedSegmentLength * mix(phaseB, phaseF, 0.8) * waterScatteringCoefficients * vec3(sunAngle < 0.5 ? sunIrradiance : moonIrradiance) * 0.1;
}
#endif