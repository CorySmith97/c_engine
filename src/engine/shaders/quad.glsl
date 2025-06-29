@header const m = @import("../util/math.zig")
@ctype mat4 m.Mat4

@vs vs
layout(binding=0) uniform vs_params {
    mat4 mvp;
};

in vec3 position;
in vec4 color;

out vec4 outcolor;

void main() {
    gl_Position = mvp * vec4(position, 1.0);
    outcolor = color;
}
@end

@fs fs
in vec4 outcolor;

out vec4 frag_color;

void main() {
    frag_color = outcolor;
}
@end

@program quad vs fs
