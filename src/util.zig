const math = @import("math.zig");
const mat4 = math.Mat4;
const shd = @import("shaders/basic.glsl.zig");
const ig = @import("cimgui");

pub fn computeVsParams(proj: mat4, view: mat4) shd.VsParams {
    const model = mat4.identity();
    //const rxm = mat4.rotate(rx, .{ .x = 1.0, .y = 0.0, .z = 0.0 });
    //const rym = mat4.rotate(ry, .{ .x = 0.0, .y = 1.0, .z = 0.0 });
    //const model = mat4.mul(rxm, rym);
    //const aspect = app.widthf() / app.heightf();
    //const proj = mat4.persp(60, aspect, 0.01, 100);
    return shd.VsParams{ .mvp = mat4.mul(mat4.mul(proj, view), model) };
}

pub fn aabb(point: ig.ImVec2_t, pos: ig.ImVec2_t, size: ig.ImVec2_t) bool {
    const is_point_inside = point.x >= pos.x and point.x <= pos.x + size.x and
        point.y >= pos.y and point.y <= pos.y + size.y;
    return is_point_inside;

}