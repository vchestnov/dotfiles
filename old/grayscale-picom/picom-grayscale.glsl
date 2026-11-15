#version 330
in vec2 texcoord;

uniform sampler2D tex;
uniform float opacity;

vec4 default_post_processing(vec4 c);

vec4 window_shader() {
    vec4 c = default_post_processing(texelFetch(tex, ivec2(texcoord), 0));
    float y = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    c = opacity*vec4(y, y, y, c.a);
    return c;
}
