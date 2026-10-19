
/*  
const int colortex0Format =     RGBA8;
const int colortex1Format =     RG32UI;
const int colortex2Format =     R11F_G11F_B10F;
const int colortex3Format =     R32UI;

const int colortex4Format =     RGBA16F;
const int colortex5Format =     RGBA16F;
const int colortex6Format =     RG32UI;

const int colortex7Format =     RGBA16F;
const int colortex8Format =     RGBA16F;
const int colortex9Format =     RGBA16F;
const int colortex10Format =    RGBA8;
const int colortex11Format =    RGBA8;
const int colortex12Format =    RGBA8;
const int colortex13Format =    RGBA8;
const int colortex14Format =    RGBA8;
const int colortex15Format =    RGBA8;

const int shadowcolor1Format =  RGBA8;
*/

const bool colortex0Clear =     false;
const bool colortex1Clear =     false;
const bool colortex2Clear =     false;
const bool colortex3Clear =     false;
const bool colortex4Clear =     false;
const bool colortex5Clear =     false;
const bool colortex6Clear =     false;
const bool colortex7Clear =     false;
const bool colortex8Clear =     false;
const bool colortex9Clear =     false;
const bool colortex10Clear =    false;
const bool colortex11Clear =    false;
const bool colortex12Clear =    false;
const bool colortex13Clear =    false;
const bool colortex14Clear =    false;
const bool colortex15Clear =    false;
const bool shadowcolor0Clear =  false;
const bool shadowcolor1Clear =  false;

const vec4 colortex0ClearColor =    vec4(0.545, 0.678, 0.894,1);
const vec4 colortex1ClearColor =    vec4(0,0,0,0);
const vec4 shadowcolor0ClearColor = vec4(0,0,0,0);
const vec4 colortex8ClearColor =    vec4(0.0, 0.0, 0.0, 1.0);

const bool shadowHardwareFiltering = true;

/*
gbuffers:
0: albedo, lightmap
1: geometry
2: emission
3: zwidth, gbaa weights
deffered:
4: diffuse history
5: specular history
6: previous frame geometry
7: scene color
8: cloud accumulation
*/