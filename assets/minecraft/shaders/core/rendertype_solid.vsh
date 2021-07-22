#version 150

#moj_import <light.glsl>

const float EPSILON = 0.001;
const float SQRT2_2 = 0.7071067811865476;

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ChunkOffset;

out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out vec3 normal;
out vec3 vertexPos;
out float isCuboid;
out mat4 mvp;

void main() {
    vertexPos = Position + ChunkOffset;
    texCoord0 = UV0;
    
    vec3 viewDirection = normalize(vertexPos);//(vec4(0, 0, 1, 0) * ModelViewMat).xyz;
    isCuboid = (abs(Normal.y) > 0.75 && fract(Position.y) < EPSILON) ? 1 : 0;
    if (Normal.y > 0.75 && fract(Position.y) < EPSILON) {
        float viewDot;
        vec2 direction = vec2(-SQRT2_2, SQRT2_2);
        if (gl_VertexID % 4 == 0) {
            // -X -Z
            viewDot = dot(viewDirection.xz, direction.xx);
        } else if (gl_VertexID % 4 == 1) {
            // -X +Z
            viewDot = dot(viewDirection.xz, direction.xy);
        } else if (gl_VertexID % 4 == 2) {
            // +X +Z
            viewDot = dot(viewDirection.xz, direction.yy);
        } else {
            // +X -Z
            viewDot = dot(viewDirection.xz, direction.yx);
        }
        vertexPos.y += step(SQRT2_2, viewDot);
    }

    mvp = ProjMat * ModelViewMat;

    gl_Position = mvp * vec4(vertexPos, 1.0);

    vertexDistance = length((ModelViewMat * vec4(Position + ChunkOffset, 1.0)).xyz);
    vertexColor = Color * minecraft_sample_lightmap(Sampler2, UV2);
   
    normal = Normal;
}
