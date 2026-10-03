#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uCentre;
uniform vec2 uRadii;
uniform vec3 uColour;
uniform vec2 uAlpha;
uniform vec4 uLand;
uniform vec4 uChannel;
uniform sampler2D uMask;

out vec4 fragColor;

void main() {
  vec2 point = FlutterFragCoord().xy;
  float reach = clamp(length((point - uCentre) / uRadii), 0.0, 1.0);
  float alpha = mix(uAlpha.x, uAlpha.y, reach);
  float land = dot(texture(uMask, (point - uLand.xy) / uLand.zw), uChannel);
  float shade = alpha * land;
  fragColor = vec4(uColour * shade, shade);
}
