#version 430 core

uniform sampler2D gtexture;

uniform float alphaTestRef;

in vec2 atlasCoordinates;

/* DRAWBUFFERS: */

void main() {   
    if (texture(gtexture, atlasCoordinates, -0.5).a < alphaTestRef) discard;
    
}
