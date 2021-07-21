#version 150

#moj_import <fog.glsl>

const float EPSILON = 0.001;
const float KNOB_HEIGHT = 1.5 / 16;
const int STEPS = 50;

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;
uniform vec3 ChunkOffset;

in float vertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in vec3 normal;
in vec3 vertexPos;
in float isCuboid;
in mat4 mvp;

out vec4 fragColor;

float getHeight(vec2 uv) {
    uv = mod(uv, 0.5) - 0.25;
    float dist = length(uv);
    return KNOB_HEIGHT - step(0.125, dist) * KNOB_HEIGHT;
}

bool isInside(vec2 uv) {
    uv = mod(uv, 0.5) - 0.25;
    return length(uv) < 0.12;
}

void main() {
    gl_FragDepth = gl_FragCoord.z;
    vec4 color = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    vec3 modulator = vec3(1);
    if (normal.y > 1 - EPSILON && isCuboid > 0.5) {
        vec3 pos = vertexPos;
        vec3 rayDir = normalize(pos);
        pos -= rayDir * EPSILON;
        vec2 fPos = fract(pos.xz - ChunkOffset.xz);
        float dist = length(pos);
        float distanceToTop = abs(fract(pos.y - ChunkOffset.y));
        
        if (distanceToTop < KNOB_HEIGHT) {
            vec3 distances;
            distances.y = KNOB_HEIGHT - distanceToTop;
            distances.xz = sign(rayDir.xz) * 0.5 - 0.5 + fPos;
            vec3 steps = abs(distances / rayDir);
            float minStep = min(steps.x, min(steps.y, steps.z));
            fPos -= minStep * rayDir.xz;
            distanceToTop += minStep * -rayDir.y;
        }
        float stepSize = distanceToTop / -rayDir.y / STEPS;
        float relativeY = distanceToTop;
        for (int i = 0; i < STEPS; i++) {
            float height = getHeight(fPos);

            if (relativeY < height) {
                modulator = vec3(isInside(fPos - rayDir.xz * stepSize) ? 1.0 : 0.8);
                break;
            }
            fPos += rayDir.xz * stepSize;
            pos += rayDir * stepSize;
            relativeY -= -rayDir.y * stepSize;
        }

        // Refinement
        float scaleFactor = 0.5;
        for (int i = 0; i < 5; i++) {
            float stepDir = 1;
            float height = getHeight(fPos);
            if (relativeY < height) {
                stepDir = -1;
            }
            fPos += rayDir.xz * stepSize * scaleFactor * stepDir;
            pos += rayDir * stepSize * scaleFactor * stepDir;
            relativeY -= -rayDir.y * stepSize * scaleFactor * stepDir;
            scaleFactor /= 2;
        }

        if (any(greaterThan(abs(fPos - 0.5), vec2(0.5 + 0.01))))
                discard;
        vec2 texCoord = (floor(texCoord0 * 64) + fract(fPos)) / 64;
        color = texture(Sampler0, texCoord) * vertexColor * ColorModulator * vec4(0.9);
        vec4 glpos = mvp * vec4(pos, 1);
        gl_FragDepth = glpos.z / glpos.w * 0.5 + 0.5;
    }
    color.rgb *= modulator;
    if (color.a < 0.1)
        discard;
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}
