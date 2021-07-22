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
    if (normal.y > 0.75) {
        uv = mod(uv, 0.5) - 0.25;
        float dist = length(uv);
        return KNOB_HEIGHT - step(0.125, dist) * KNOB_HEIGHT;
    } else {
        uv = abs(uv - 0.5);
        float dEdge = 0.375 - max(uv.x, uv.y);
        float dCylinder = abs(length(uv) - 0.707 / 2.0 + 0.14) - 0.015;
        float dist = min(dEdge, dCylinder);
        return 1.0 + (step(0, dist)) * 0.5 - EPSILON;
    }
}

bool isInside(vec2 uv) {
    if (normal.y > 0.75) {
        uv = mod(uv, 0.5) - 0.25;
        return length(uv) < 0.12;
    } else {
        uv = abs(uv - 0.5);
        float dEdge = 0.37 - max(uv.x, uv.y);
        float dCylinder = abs(length(uv) - 0.707 / 2.0 + 0.14) - 0.01;
        float dist = min(dEdge, dCylinder);
        return dist < 0;
    }
}

void main() {
    gl_FragDepth = gl_FragCoord.z;
    vec4 color = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    vec3 modulator = vec3(1);

    float yMul = normal.y > 0.75 ? -1 : 1;

    if (abs(normal.y) > 0.75 && isCuboid > 0.5) {
        vec3 pos = vertexPos;
        vec3 rayDir = normalize(pos);
        pos -= rayDir * EPSILON;
        vec3 fPos = fract(pos - ChunkOffset);
        
        if (normal.y > 0.75 && fPos.y < KNOB_HEIGHT) {
            vec3 distances;
            distances.y = fPos.y - KNOB_HEIGHT;
            distances.xz = sign(rayDir.xz) * 0.5 - 0.5 + fPos.xz;
            vec3 steps = abs(distances / rayDir);
            float minStep = min(steps.x, min(steps.y, steps.z));
            fPos -= minStep * rayDir;
            pos -= minStep * rayDir;
        }

        float stepSize = fPos.y / rayDir.y / STEPS * yMul;
        for (int i = 0; i < STEPS; i++) {
            float height = getHeight(fPos.xz);

            if ((normal.y > 0.75 && fPos.y < height) || (normal.y < -0.75 && fPos.y > height)) {
                modulator = vec3(isInside(fPos.xz - rayDir.xz * stepSize) ? 1.0 : 0.8);
                break;
            }

            fPos += rayDir * stepSize;
            pos += rayDir * stepSize;
        }

        if (any(greaterThan(abs(fPos.xz - 0.5), vec2(0.5 + 0.01))))
                discard;
        
        // Refinement
        float scaleFactor = 0.5;
        for (int i = 0; i < 5; i++) {
            float stepDir = 1;
            float height = getHeight(fPos.xz);
            if ((normal.y > 0.75 && fPos.y < height) || (normal.y < -0.75 && fPos.y > height)) {
                stepDir = -1;
            }
            fPos += rayDir * stepSize * scaleFactor * stepDir;
            pos += rayDir * stepSize * scaleFactor * stepDir;
            scaleFactor /= 2;
        }

        vec2 texCoord = (floor(texCoord0 * 64) + fract(fPos.xz)) / 64;
        color = texture(Sampler0, texCoord) * vertexColor * ColorModulator * vec4(0.9);
        vec4 glpos = mvp * vec4(pos, 1);
        gl_FragDepth = glpos.z / glpos.w * 0.5 + 0.5;
    }
    color.rgb *= modulator;
    if (color.a < 0.1)
        discard;
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}