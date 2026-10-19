float hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 temperatureToRGB(float T) {
    float temp = clamp(T, 600.0, 40000.0) / 100.0;

    float r = temp <= 66.0 ? 1.0 : clamp(1.292936186062745 * pow(temp - 60.0, -0.1332047592), 0.0, 1.0);
    float g = temp <= 66.0
        ? clamp(0.3900815787690196 * log(temp) - 0.6318414437886275, 0.0, 1.0)
        : clamp(1.129890860895294 * pow(temp - 60.0, -0.0755148492), 0.0, 1.0);
    float b = temp >= 66.0 ? 1.0 : (temp <= 19.0 ? 0.0 : clamp(0.543206789110196 * log(temp - 10.0) - 1.19625408914, 0.0, 1.0));

    return vec3(r,g,b);
}

vec3 rotateAroundAxis(vec3 v, vec3 axis, float angle) {
    float cosA = cos(angle);
    float sinA = sin(angle);
    return v * cosA + cross(axis, v) * sinA + axis * dot(axis, v) * (1.0 - cosA);
}

vec3 getStars(vec3 D, float sunAngle) {
    
    D = rotateAroundAxis(D, normalize(vec3(0,-1,-1)), fract(sunAngle + 0.75) * M_PI * 1);
    
    vec2 tile = round(octaEncode(D) * 300);
    vec3 center = normalize(octaDecode(tile / 300));
    return clamp((1.0 - (distance(D, center)) * 700 * (0.6 + sqrt(hash12(tile + 228)))) * 1, 0.0, 1.0) * step(0.955, hash12(tile)) * temperatureToRGB(100.0 + hash12(tile - 231) * 20000.0) * pow(hash12(tile + 25), 3) * 10 * (step(0.995, hash12(tile)) * 0.99 + 0.01);
}

vec2 raySphereIntersection(vec3 O, vec3 D, vec3 S, float r) {
    vec3 SO = O - S;
    float a = dot(D, D);
    float b = 2.0 * dot(D, SO);
    float c = dot(SO, SO) - r * r;
    float disc = b * b - 4.0 * a* c;
    if (disc < 0.0) {
        return vec2(-1.0, -1.0);
    }else{
		return vec2(-b - sqrt(disc), -b + sqrt(disc)) / (2.0 * a);
	}
}

const vec3 moonPhases[] = {
    vec3(-0.2, 0.0, -1.0),
    vec3(-0.2, 1.0, -1.0),
    vec3(-0.3, 1.0,  0.0),
    vec3(-0.5, 1.0,  0.5),
    vec3(-0.7, 0.2, 1.0),
    vec3(-0.5, -1.0,  0.7),
    vec3(-0.3, -1.0,  0.0),
    vec3(-0.2, -1.0, -1.0)
};

vec2 mapSphere(vec3 D) {
    float u = 0.5 + atan(D.z, D.x) / (2.0 * 3.14);
    float v = 0.5 + asin(D.y) / 3.14;
    return vec2(u, v);
}
vec3 getSkyColor(vec3 view, vec3 sun, float sunAngle, sampler2D skytex) {
    
    vec3 space = vec3(0);
    space += getStars(view, sunAngle) * 0.1;
    space += step(cos(radians(0.625)), dot(view, sun)) * sunRadiance;
    //space += step(cos(radians(0.625)), dot(view,-sun)) * moonRadiance;
    vec2 moonT = raySphereIntersection(vec3(0), view, -sun, 0.015);
    if (moonT.x > 0.0) {
        vec3 moonHit = view * moonT.x;
        vec3 moonNormal = (moonHit - (-sun)) / moonAngularRadius;
        
        int phase = moonPhase;
        
        float Zl = saturate(dot(moonNormal, normalize(vec3(0, moonPhases[phase].xy) - sun * moonPhases[phase].z)));
        
        space = saturate((moonT.y - moonT.xxx) * 100.0) * vec3(Zl * moonRadiance) + 0.0001;
        space.xyz *= textureLod(moontex, mapSphere(-moonNormal.zyx), 0).rgb;
    }
    
    vec2 skytexUv = atmo_directionToEnvMapCoords(view, sun);
    vec3 inscattering = textureLod(skytex, skytexUv, 0).rgb;
    vec3 transmittance = textureLod(skytex, skytexUv + vec2(0, 0.5), 0).rgb;
    
    vec3 color = space * transmittance + inscattering;
    
    return color;
}