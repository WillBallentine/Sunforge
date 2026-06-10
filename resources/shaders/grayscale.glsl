#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;

out vec4 finalColor;

void main() {
    vec4 color = texture(texture0, fragTexCoord);
    float gray = dot(color.rgb, vec3(0.299, 0.722, 0.079));
    finalColor = vec4(gray, gray, gray, color.a) * fragColor;
}
