
struct fragPosData {
    vec3 fragCoord;
    vec3 position;
    vec3 view;
};

fragPosData buildFragPos(vec2 fragCoord, float depth) {
    fragPosData fp;
    fp.fragCoord = vec3(fragCoord, depth);
    fp.position = projectPoint(vec3(fragCoord * resolutionInv, depth) * 2.0 - 1.0, gbufferProjectionInverse);
    fp.view = normalize(fp.position);
    return fp;
}

vec2 getMediaInterface(bool isWater) {
    const float waterIOR = 1.25;
    const float glassIOR = 1.45;
    vec2 mediaInterface;
    mediaInterface.x = isEyeInWater == 1 ? waterIOR : 1.0;
    mediaInterface.y = isWater ? (isEyeInWater == 1 ? 1.0 : waterIOR) : glassIOR;
    return mediaInterface;
}

vec2 edgeDist(vec2 p) {
    p += 0.2;
    vec2 edgeDistPixels = min(p, 1.4 - p);
    return saturate(edgeDistPixels * 1.5);
}

vec3 getRefractionPosition(fragPosData fp, vec3 normal, vec3 trueNormal, float eta, float thickness) {
    
    vec3 direction = refract(fp.view, normal, eta);
    vec3 F = projectPoint(fp.position + direction * thickness, gbufferProjection) * 0.5 + 0.5;
    
    vec3 directionFB = refract(fp.view, trueNormal - normal, eta);
    vec3 FFB = projectPoint(fp.position + directionFB * thickness, gbufferProjection) * 0.5 + 0.5;
    
    vec3 cF = projectPoint(fp.position + fp.view * thickness, gbufferProjection) * 0.5 + 0.5;
    vec3 O = fp.fragCoord * vec3(resolutionInv, 1.0); 
    
    vec3 P = O;
    vec3 P1 = P;
    
    int i;
    for (i = 0; i<7; i++) {
        P1 = mix(O, F, (i + 0.5) / 7.0);
        float screenDepth = textureLod(depthtex1, P1.xy, 0).r;
        if (screenDepth < P1.z) {
            break;
        }
        P = P1;
    }
    
    float zStep = (F.z - O.z) / 7.0;
    
    float d0 = textureLod(depthtex1, P.xy, 0).r;
    float d1 = textureLod(depthtex1, P1.xy, 0).r;
    float z0 = d0-P.z;
    float z1 = d1-P1.z;
    float f = (z0/(z0-z1));
    if (f == clamp(f, 0.0, 1.0)) P = mix(P, P1, f);
    
    if(eta < 1.0) {
        vec4 bgDepthS = textureGather(depthtex1, P.xy, 0);
        float bgDepth = min(min(bgDepthS.x, bgDepthS.y), min(bgDepthS.z, bgDepthS.w));
        if (saturate(P.xy) != P.xy || (abs(bgDepth-P.z) > abs(zStep * 0.5) && bgDepth < F.z)) P = FFB;
        
        vec4 ffbDepth = textureGather(depthtex1, P.xy, 0);
        if (any(lessThan(ffbDepth, O.zzzz - 0.0001))) P = O;
    }
    P.z = textureLod(depthtex1, P.xy, 0).r;
    return P;
    
}

// https://en.wikipedia.org/wiki/Fresnel_equations
float fresnel(float cosTheta, float n1, float n2) {
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    
    float a = min(1.0, n1 / n2 * sinTheta);
    float s = sqrt(1.0 - a * a);
    
    float ts = (n1 * cosTheta - n2 * s) / (n1 * cosTheta + n2 * s);
    float tp = (n1 * s - n2 * cosTheta) / (n1 * s + n2 * cosTheta);
    
    float reflectance = (ts * ts + tp * tp) * 0.5;
    return reflectance;
}

vec2 wave(vec2 position, vec2 direction, float scale, float timeScale) {
    float speed = sqrt(9.8 * 2.0 * M_PI * scale);
    float x = (dot(position, direction) + frameTimeCounter * timeScale) * scale * 2.0 * M_PI * speed;
    float waveX = -exp(sin(x) - 1.0) * cos(x);
    return direction * waveX;
}

vec3 getWaterNormal(vec3 position, vec3 normal, float mipBlend) {
    float NdotV = sqrt(saturate(dot(normal, -normalize(position))));
    normal = mat3(gbufferModelViewInverse) * normal;
    vec2 pos = (gbufferModelViewInverse * vec4(position, 1)).xz + cameraPosition.xz;
    //pos = round(pos * 16.0) / 16.0;
    
    vec2 pool = vec2(0);
    float poolScale = 0.3;

    float freq = 1.0;
    float scale = 1.0;
    uint seed = 2;
    for (int i = 0; i<24; i++) {
        float scale = 0.1 + rnd(seed);
        float freq = 0.5 + rnd(seed);
        float rdir = rnd(seed) * 3.14 * 2.0;
        
        vec2 dir = vec2(sin(rdir), cos(rdir));
        pool += wave(pos, dir, freq * poolScale, 0.5) * scale;
    }
    
    for (int i = 0; i<8; i++) {
        float r = rnd(seed);
        
        float scale = (1.2 - r) * 0.3;
        float freq = 3.5 + r * 3;
        float rdir = rnd(seed) * 3.14 * 2.0;
        
        vec2 dir = vec2(sin(rdir), cos(rdir));
        pool += wave(pos, dir, freq * poolScale, 0.5) * scale;
    }
    
    
    pool *= 0.03;
    pool *= NdotV;
    
    pool += wave(pos,  vec2( 0.327, 0.945) , 0.07, 1.0) * 0.03;
    pool += wave(pos,  vec2(-0.811, -0.585), 0.09, 1.0) * 0.03;
    pool += wave(pos,  vec2( 0.998, -0.063), 0.06, 1.0) * 0.03;
    pool += wave(pos,  vec2(-0.456, 0.890) , 0.11, 1.0) * 0.03;
    pool += wave(pos,  vec2( 0.032, -0.999), 0.10, 1.0) * 0.03;
    
    pool *= saturate(abs(normal.y) * 0.5 + 0.5);
    
    mat3 TBN = mat3(vec3(1,0,0),vec3(0,0,1), normal);
    
    normal = normalize(TBN * vec3(pool * (1.0 - mipBlend), 1.5));
    
    
    normal = mat3(gbufferModelView) * normal;
    return normal;
}

float viewToScreenScale(float z) {
    return gbufferProjectionInverse[0][0] * resolution.x / -z * 0.25;
}

vec3 getReflection(fragPosData fragPos, vec3 normal, vec2 lightmap, float microDetailsBlend, vec3 sun, ivec2 fragCoord) {
    vec3 reflectedDir = reflect(fragPos.view, normal);
    vec2 uv = atmo_directionToEnvMapCoords(mat3(gbufferModelViewInverse) * reflectedDir, sun);
    vec3 skyColor = textureLod(skytex, uv, 0).rgb * lightmap.y;
    if (isEyeInWater==1) skyColor *= 0.01;
    
    vec4 rayData = ssrt_Ray(fragPos.position, reflectedDir, fragPos.fragCoord, true, 120);
    
    vec4 hit = rayData;
    hit.xy *= resolutionInv;
    vec3 hitPosition = projectPoint(hit.xyz * 2.0 + -1.0, gbufferProjectionInverse);
    float t = distance(fragPos.position, hitPosition);
    
    float zScale = viewToScreenScale(hitPosition.z);
    
    float radius = min(t * zScale * (0.05 * microDetailsBlend + 0.003), 8);
    
    rayData.a *= edgeFade(rayData.xy, fragCoord + 0.5);
    
    return mix(skyColor, textureLod(colortex7, rayData.xy * resolutionInv,  log2(radius)).rgb, rayData.a);
}