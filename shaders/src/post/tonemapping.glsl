#include "aces.glsl"

#define TONEMAP_OPERATOR tonemapVTXS // [tonemapVTXS tonemapACESFitted tonemapLottes tonemapReinhard]

//Timothy Lottes [AMD], "Advanced Techniques and Optimization of HDR VDR Color Pipelines"
// https://gpuopen.com/wp-content/uploads/2016/03/GdcVdrLottes.pdf
vec3 tonemapLottes(vec3 color) {
	const float contrast =  1.3;
    const float shoulder =  0.995;
    const float midIn =     0.28;
    const float midOut =    0.32;
    const float hdrMax =    8.0;
    
    const float a = contrast;
    const float d = shoulder;
    const float b = (-pow(midIn, a) + pow(hdrMax, a) * midOut) / 
                    ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
           
    const float c = (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
                    ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);


    color = pow(color, vec3(contrast));
    color /= pow(color, vec3(shoulder)) * b + c;
	return color;
}

vec3 tonemapReinhard(vec3 color) {
    color /= color + 1.0;
    return color;
}

vec3 tonemapVTXS(vec3 color) {
    const float rgInterface = 1.0;
    const float gbInterface = 1.0;
    const float brInterface = 0.4;
    
    const vec3 sensorPiercing = vec3(0.63, 0.54, 0.46) * 0.04;
    
    vec3 pColor = color * sensorPiercing * smoothstep(0.0, 1.0, color);
    
    color.r += (pColor.g * rgInterface) + (pColor.b * brInterface) - pColor.r * (rgInterface + brInterface);
    color.g += (pColor.r * rgInterface) + (pColor.b * gbInterface) - pColor.g * (rgInterface + gbInterface);
    color.b += (pColor.r * brInterface) + (pColor.g * gbInterface) - pColor.b * (brInterface + gbInterface);
    
    color = pow(color, vec3(1.2));
    color /= color + 1.0;
    color = pow(color, vec3(1.17));
    return color;
}
