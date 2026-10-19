#include "/src/utils/blue_noise.glsl"

mat3 createOrthonormalMatrix(vec3 N) {
  vec3 T;
  if(abs(N.x) > abs(N.y))
    T = vec3(N.z, 0, -N.x) / sqrt(N.x * N.x + N.z * N.z);
  else
    T = vec3(0, -N.z, N.y) / sqrt(N.y * N.y + N.z * N.z);
  
  return mat3(T, cross(N, T), N);
}




//  "Sampling the GGX Distribution of Visible Normals", Eric Heitz
//  https://jcgt.org/published/0007/04/01/paper.pdf

vec3 sampleGGXVNDF(vec3 Ve, float alpha, vec2 circle)
{
// Section 3.2: transforming the view direction to the hemisphere configuration
vec3 Vh = normalize(vec3(alpha * Ve.xy, Ve.z));
// Section 4.1: orthonormal basis (with special case if cross product is zero)
float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
vec3 T1 = lensq > 0 ? vec3(-Vh.y, Vh.x, 0) * inversesqrt(lensq) : vec3(1,0,0);
vec3 T2 = cross(Vh, T1);
// Section 4.2: parameterization of the projected area
vec2 t = circle * 0.999;
float s = 0.5 * (1.0 + Vh.z);
t.y = (1.0 - s)*sqrt(1.0 - t.x*t.x) + s*t.y;
// Section 4.3: reprojection onto hemisphere
vec3 Nh = t.x*T1 + t.y*T2 + sqrt(max(0.0, 1.0 - dot(t,t)))*Vh;
// Section 3.4: transforming the normal back to the ellipsoid configuration
vec3 Ne = normalize(vec3(alpha * Nh.xy, max(0.0, Nh.z)));
return Ne;
}

float pdfVNDF(vec3 V, vec3 D, float alpha) {   
    float alphaSq = alpha * alpha;
    vec3 N = normalize(D + V);
    float nrm = 1.0 / sqrt((V.z * V.z) * (1.0 - alphaSq) + alphaSq);
    float sigmaStd = (V.z * nrm) * 0.5 + 0.5;
    float sigmaI = sigmaStd / nrm;
    float nrmN = (N.z * N.z) * (alphaSq - 1.0) + 1.0;
    return alphaSq / (M_PI * 4.0 * nrmN * nrmN * sigmaI);
}


float fresnelSchlick(float cosTheta, float F0) //cosTheta == Zh
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

struct raySamplingData {
    vec3 direction;
    float PDF;
    bool isSpecular;
    float specularProbability;
};



raySamplingData generateDirectionPDF(material surface, vec3 view, ivec2 fragCoord) {
    
    vec4 randomDir = blueNoise(ivec3(fragCoord, frameCounter));
    
    mat3 tbn = createOrthonormalMatrix(surface.normal);
    
    view = view * tbn;
    
    vec3 rTune = surface.roughness < SMOOTH_REFLECTION_THRESHOLD ? vec3(0.7, 0.4, 0.9) : vec3(1.0);
    vec3 microfacetNormal = sampleGGXVNDF(view, max(surface.roughness * rTune.x, 0.005), randomDir.xy * rTune.yz);
    vec3 directionSpecular = -reflect(view, microfacetNormal);
    vec3 directionDiffuse = randomDir.xyz;
    directionDiffuse.z = directionDiffuse.z * 0.98 + 0.02;
    
    
    float fresnelGuess = fresnelSchlick(saturate(view.z), surface.f0);
    float specularProbability = clamp(fresnelGuess, 0.0, 0.9);
    specularProbability = 1 - (1 - specularProbability) * (1 - (1 - dot(surface.albedo, vec3(0.2126, 0.7152, 0.0722))) * 0.5);

    
    
    if (surface.roughness < SMOOTH_REFLECTION_THRESHOLD) specularProbability = 1.0 - (1.0 - specularProbability) * 0.3;
    if (surface.f0 > 229.0 / 255.0) specularProbability = 1;
    
    bool isSpecular = randomDir.w < specularProbability;
    raySamplingData raySample;
    
    vec3 direction = isSpecular ? directionSpecular : directionDiffuse;
    
    //if (dot(tbn * direction, surface.trueNormal) < 0.0 || direction.z < 0) return raySamplingData(vec3(0), -1);
    
    if (direction.z < 0) direction = directionDiffuse;
    
    raySample.direction = normalize(tbn * direction);
    raySample.isSpecular = isSpecular;
    raySample.specularProbability = specularProbability;
    
    if (dot(raySample.direction, surface.trueNormal) < 0.0) raySample.direction = reflect(raySample.direction, surface.trueNormal);
    
    
    float pdfSpecular = pdfVNDF(view, direction, max(0.002, surface.roughness * rTune.x));
    float pdfDiffuse = direction.z / M_PI;
    if (surface.roughness < SMOOTH_REFLECTION_THRESHOLD)
      raySample.PDF = mix(pdfDiffuse, pdfSpecular, isSpecular);
    else
      raySample.PDF = mix(pdfDiffuse, pdfSpecular, specularProbability);
    
    
    return raySample;
}

vec2 lowpFilter(float roughness, float probabilityB, bool isB) {
    if (roughness > SMOOTH_REFLECTION_THRESHOLD) return vec2(1);
    float A = float(!isB) / (1.0 - probabilityB); 
    float B = float(isB) / (probabilityB); 
    if (probabilityB == 1.0) A = 0.0;
    if (probabilityB == 0.0) B = 0.0;
    return vec2(A,B);
}

float getRoughnessHeuristic(float roughness) {
    float roughnessHeuristic = 1.0 - 2.0 * roughness;
    roughnessHeuristic *= roughnessHeuristic * roughnessHeuristic;
    roughnessHeuristic = saturate(roughnessHeuristic);
    if (roughness < SMOOTH_REFLECTION_THRESHOLD) roughnessHeuristic = 1.0;
    return roughnessHeuristic;
}


raySamplingData generateDirectionPDF(uvec3 surface, vec3 view, ivec2 fragCoord) {
    float roughness = getRoughness(surface);
    float f0 = getF0(surface);
    
    vec4 randomDir = blueNoise(ivec3(fragCoord, frameCounter));
    
    view = view * createOrthonormalMatrix(getNormal(surface));
    
    vec3 rTune = roughness < SMOOTH_REFLECTION_THRESHOLD ? vec3(0.7, 0.4, 0.9) : vec3(1.0);
    vec3 microfacetNormal = sampleGGXVNDF(view, max(roughness * rTune.x, 0.005), randomDir.xy * rTune.yz);
    vec3 directionSpecular = -reflect(view, microfacetNormal);
    vec3 directionDiffuse = randomDir.xyz;
    directionDiffuse.z = directionDiffuse.z * 0.98 + 0.02;
    
    
    float fresnelGuess = fresnelSchlick(saturate(view.z), f0);
    float specularProbability = clamp(fresnelGuess, 0.0, 0.9);
    specularProbability = 1 - (1 - specularProbability) * (1 - (1 - dot(getAlbedo(surface), vec3(0.2126, 0.7152, 0.0722))) * 0.5);

    
    
    if (roughness < SMOOTH_REFLECTION_THRESHOLD) specularProbability = 1.0 - (1.0 - specularProbability) * 0.4;
    if (f0 > 229.0 / 255.0) specularProbability = 1;
    
    bool isSpecular = randomDir.w < specularProbability;
    raySamplingData raySample;
    
    vec3 direction = isSpecular ? directionSpecular : directionDiffuse;
    
    //if (dot(tbn * direction, surface.trueNormal) < 0.0 || direction.z < 0) return raySamplingData(vec3(0), -1);
    
    if (direction.z < 0) direction = directionDiffuse;
    
    raySample.direction = normalize(createOrthonormalMatrix(getNormal(surface)) * direction);
    raySample.isSpecular = isSpecular;
    raySample.specularProbability = specularProbability;
    
    //if (dot(raySample.direction, surface.trueNormal) < 0.0) raySample.direction = reflect(raySample.direction, surface.trueNormal);
    
    
    float pdfSpecular = pdfVNDF(view, direction, max(0.002, roughness * rTune.x));
    float pdfDiffuse = direction.z / M_PI;
    if (roughness < SMOOTH_REFLECTION_THRESHOLD)
      raySample.PDF = mix(pdfDiffuse, pdfSpecular, isSpecular);
    else
      raySample.PDF = mix(pdfDiffuse, pdfSpecular, specularProbability);
    
    
    return raySample;
}