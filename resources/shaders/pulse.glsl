#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform float time;

out vec4 finalColor;

void main() {
    vec4 color = texture(texture0, fragTexCoord);
    float pulse = 0.85 + 0.15 * sin(time * 3.0);
    finalColor = vec4(color.rgb * pulse, color.a) * fragColor;
}
