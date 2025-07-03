@header const m = @import("../util/math.zig")
@ctype mat4 m.Mat4

@vs vs
layout(binding=0) uniform vs_params {
    mat4 mvp;
};

in vec3 position;
in vec2 uv_coords;
in vec4 pos;
in vec4 color;

out vec2 uv;
out float id;
out vec4 ocolor;

void main() {
    gl_Position = mvp * vec4((position * 16) + pos.xyz, 1.0);
    id = pos.a;
    uv = uv_coords;
    ocolor = color;
}
@end

@fs fs
layout(binding=0) uniform texture2D tex2d;
layout(binding=0) uniform sampler smp;
layout(binding=1) uniform fs_params {
    vec2 atlas_size;
    vec2 sprite_size;
};

in vec2 uv;
in float id;
in vec4 ocolor;

out vec4 frag_color;

void main() {
     float total_rows = atlas_size.y / sprite_size.y;
     float sprites_per_row = atlas_size.x / sprite_size.x;
     float row = total_rows - 1.0 - floor(id / sprites_per_row);
     float col = mod(id, sprites_per_row);

     vec2 sprite_offset = vec2(col * sprite_size.x, row * sprite_size.y);
     vec2 fixedTexCoord = vec2(uv.x, uv.y);

     vec2 sprite_uv = (sprite_offset + fixedTexCoord * sprite_size) / atlas_size;



     vec4 original = texture(sampler2D(tex2d, smp), sprite_uv);

     vec4 finalColor = (original.a > 0.1)
          ? original : ocolor;
     frag_color = finalColor;
}
@end

@program basic vs fs


@vs vs2
layout(binding=0) uniform vs_params {
    mat4 mvp;
};

in vec3 position;
in vec2 uv_coords;
in vec4 pos;
in vec4 color;

out vec2 uv;
out float id;
out vec4 ocolor;

void main() {
    gl_Position = mvp * vec4((position * 16) + pos.xyz, 1.0);
    id = pos.a;
    uv = uv_coords;
    ocolor = color;
}
@end

@fs fs2
layout(binding=0) uniform texture2D tex2d;
layout(binding=0) uniform sampler smp;
layout(binding=1) uniform fs_params {
    vec2 atlas_size;
    vec2 sprite_size;
};

in vec2 uv;
in float id;
in vec4 ocolor;

out vec4 frag_color;

void main() {
     float total_rows = atlas_size.y / sprite_size.y;
     float sprites_per_row = atlas_size.x / sprite_size.x;
     float row = total_rows - 1.0 - floor(id / sprites_per_row);
     float col = mod(id, sprites_per_row);

     vec2 sprite_offset = vec2(col * sprite_size.x, row * sprite_size.y);
     vec2 fixedTexCoord = vec2(uv.x, uv.y);

     vec2 sprite_uv = (sprite_offset + fixedTexCoord * sprite_size) / atlas_size;



     vec4 original = texture(sampler2D(tex2d, smp), sprite_uv);

     vec4 finalColor = (original.a > 0.1)
          ? original : ocolor;
     frag_color = finalColor;
}
@end

@program second vs2 fs2
