//  PBR Functions: GGX Distribution, Schlick Fresnel, Smith Geometry
//  https://learnopengl.com/PBR/Theory

float DistributionGGX(float Zh, float a)
{   
    
    float a2     = a*a; 
    float NdotH  = max(Zh, 0.0); 
    float NdotH2 = NdotH*NdotH; 
	
    float nom    = a2; 
    float denom  = (NdotH2 * (a2 - 1.0) + 1.0);
    denom        = M_PI * denom * denom; 
	
    return nom / denom;
}


float GeometrySmith(float Zv, float Zl, float a)
{   
    float k = (a + 1.0);
    k = (k * k) / 8.0;
    float ggx1 = 1.0 / (Zv * (1.0 - k) + k);
    float ggx2 = Zl / (Zl * (1.0 - k) + k);
	
    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) 
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}




struct radianceSeparate {
    vec3 diffuse;
    vec3 specular;
};

radianceSeparate BRDF(vec3 light, vec3 view, material surface) {
    //if (dot(surface.normal, view) < 0.0) surface.normal = (cross(cross(view, surface.normal), view));
    
    vec3 H = normalize(view + light);
    float VdotH = saturate(dot(view, H));
    float Zh = saturate(dot(surface.normal, H));
    float Zl = saturate(dot(surface.normal, light));
    float Zv = saturate(dot(surface.normal, view));
    
    
    float D = DistributionGGX(Zh, surface.roughness);
    float G = GeometrySmith(Zv, Zl, surface.roughness);
    vec3  F = fresnelSchlick(VdotH, surface.f0 > 229.0 / 255.0 ? surface.albedo : surface.f0.xxx);
    
    radianceSeparate radiance;
    radiance.diffuse = Zl * (surface.f0 > 229.0 / 255.0 ? vec3(0) : (1.0 - F) / M_PI);
    radiance.specular = D * F * G / 4.0;
    return radiance;
}

radianceSeparate BRDF(vec3 light, vec3 view, uvec3 surface) {
    vec3 normal = getNormal(surface);
    float roughness = getRoughness(surface);
    float f0 = getF0(surface);
    
    
    vec3 H = normalize(view + light);
    float VdotH = saturate(dot(view, H));
    float Zh = saturate(dot(normal, H));
    float Zl = saturate(dot(normal, light));
    float Zv = saturate(dot(normal, view));
    
    
    float D = DistributionGGX(Zh, roughness);
    float G = GeometrySmith(Zv, Zl, roughness);
    vec3  F = fresnelSchlick(VdotH, f0 > 229.0 / 255.0 ? getAlbedo(surface) : f0.xxx);
    
    radianceSeparate radiance;
    radiance.diffuse = Zl * (f0 > 229.0 / 255.0 ? vec3(0) : (1.0 - F) / M_PI);
    radiance.specular = D * F * G / 4.0;
    return radiance;
}

