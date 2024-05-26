#version 330 core

in vec3 vertex_position;
in vec2 vertex_uv;
in vec4 vertex_color;

uniform sampler2D texture_id;
uniform vec4 fog_color;
uniform vec3 camera_position;

out vec4 out_color;

float rangeNormalize(float n, float min1, float max1, float min2, float max2) {
	return (max2 - min2) / (max1 - min1) * (n - max1) + max2;
}

void main() {
    out_color = mix(
        texture(texture_id, vertex_uv) * vertex_color,
        fog_color,
        min(rangeNormalize(
            max(0, distance(camera_position, vertex_position) - 30),
            0, 100,
            0, 1
        ), 1)
    );
}
