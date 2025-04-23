@header const m = @import("../util/math.zig")
@ctype mat4 m.Mat4

@vs vs
layout(binding=0) uniform vs_params {
    mat4 mvp;
};

in vec3 position;
in vec3 color;

out vec3 outcolor;

void main() {
    gl_Position = mvp * vec4((position * 16), 1.0);
}
@end

@fs fs
in vec3 outcolor;

out vec4 frag_color;

void main() {
    frag_color = vec4(outcolor, 1.0);
}
@end

@program quad vs fs
