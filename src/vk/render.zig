const std = @import("std");
const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "");
    @cInclude("GLFW/glfw3.h");
    @cInclude("vulkan/vulkan.h");
});

const assert = std.debug.assert;
const builtin = @import("builtin");
const ArrayList = std.ArrayList;

const required_mac_support: []const [*c]const u8 = &[_][*c]const u8{
    "VK_KHR_portability_subset",
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};

const validationLayers: []const [*c]const u8 = &[_][*c]const u8{
    "VK_LAYER_KHRONOS_validation",
};

const extension_support: []const [*c]const u8 = &[_][*c]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};


const enableValidationLayers = if (builtin.mode == .Debug) true else false;


const QueueFamilyIndices = struct {
    graphics_family: ?u32 = null,
    present_family: ?u32 = null,

    fn isComplete(self: *QueueFamilyIndices) bool {
        return if (self.graphics_family != null and self.present_family != null) true else false;
    }
};

const SwapchainDetails = struct {
    capabilities  : c.VkSurfaceCapabilitiesKHR,
    formats       : std.ArrayList(c.VkSurfaceFormatKHR),
    present_modes : std.ArrayList(c.VkPresentModeKHR),

    pub fn init(
        self: *SwapchainDetails,
        allocator: std.mem.Allocator
    ) void {
        self.formats = std.ArrayList(c.VkSurfaceFormatKHR).init(allocator);
        self.present_modes = std.ArrayList(c.VkPresentModeKHR).init(allocator);
    }

    pub fn deinit(
        self: *SwapchainDetails,
    ) void {
        self.formats.deinit();
        self.present_modes.deinit();
    }

    pub fn chooseSwapchain(
        self: *SwapchainDetails,
    ) c.VkSurfaceFormatKHR {

        for (self.formats.items) |f| {
            if (f.format == c.VK_FORMAT_B8G8R8A8_SRGB and f.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
                return f;
            }
        }

        return self.formats.items[0];
    }

    pub fn chooseSwapPresentMode(
        self: *SwapchainDetails,
    ) c.VkPresentModeKHR {
        _ = self;
        return c.VK_PRESENT_MODE_FIFO_KHR;
    }

    pub fn chooseSwapExtent(
        self: *SwapchainDetails,
        window: ?*c.GLFWwindow,
    ) c.VkExtent2D {
        if (self.capabilities.currentExtent.width != std.math.maxInt(u32)) {
            return self.capabilities.currentExtent;
        } else {
            var width: i32 = 0;
            var height: i32 = 0;

            c.glfwGetFramebufferSize(window, &width, &height);

            var extent: c.VkExtent2D = .{
                .width = @intCast(width),
                .height = @intCast(height),
            };

            extent.width = std.math.clamp(extent.width, self.capabilities.minImageExtent.width, self.capabilities.maxImageExtent.width);
            extent.height = std.math.clamp(extent.height, self.capabilities.minImageExtent.height, self.capabilities.maxImageExtent.height);

            return extent;
        }
    }
};
const MAX_FRAMES: usize = 2;

//
// @todo:cs #medium I would like this  to not hold the window, but
// rather take is as a paramater. The App Module will hold all IO.
//
const Self = @This();
gpa                   : std.heap.GeneralPurposeAllocator(.{}) = undefined,
allocator             : std.mem.Allocator = undefined,
width                 : i32 = 800,
height                : i32 = 600,
window                : ?*c.GLFWwindow = undefined,
instance              : c.VkInstance = undefined,
physical_device       : c.VkPhysicalDevice = null,
device                : c.VkDevice = undefined,
debug_message         : c.VkDebugUtilsMessengerEXT = null,
surface               : c.VkSurfaceKHR = undefined,
graphics_queue        : c.VkQueue = undefined,
present_queue         : c.VkQueue = null,
swapchain             : c.VkSwapchainKHR = undefined,
swapchain_images      : std.ArrayList(c.VkImage) = undefined,
swapchain_format      : c.VkFormat = undefined,
swapchain_extent      : c.VkExtent2D = undefined,
swapchain_images_view : std.ArrayList(c.VkImageView) = undefined,
pipeline_layout       : c.VkPipelineLayout = undefined,
render_pass           : c.VkRenderPass = undefined,
graphics_pipeline     : c.VkPipeline = undefined,
framebuffers          : std.ArrayList(c.VkFramebuffer) = undefined,
command_pool          : c.VkCommandPool = undefined,
command_buffer        : ArrayList(c.VkCommandBuffer) = undefined,
image_semaphore       : ArrayList(c.VkSemaphore) = undefined,
render_semaphore      : ArrayList(c.VkSemaphore) = undefined,
in_flight_fence       : ArrayList(c.VkFence) = undefined,
current_frame         : usize = 0,



pub fn run(self: *Self) !void {
    self.gpa = .init;
    self.allocator = self.gpa.allocator();
    try self.initWindow();
    try self.initVulkan();
    try self.mainLoop();
    try self.cleanup();
}

fn initVulkan(self: *Self) !void {
    try self.createInstance();
    if (enableValidationLayers) {
        try self.setupDebugMessages();
    }
    try self.createSurface();
    try self.pickPhysicalDevice();
    try self.createLogicalDevice();
    try self.createSwapchain();
    try self.createImageViews();
    try self.createRenderPass();
    try self.createGraphicsPipeline();
    try self.createFramebuffers();
    try self.createCommandPool();
    try self.createCommandBuffer();
    try self.createSyncObjects();
}

fn createSyncObjects(
    self: *Self,
) !void {
    self.image_semaphore = ArrayList(c.VkSemaphore).init(self.allocator);
    self.render_semaphore = ArrayList(c.VkSemaphore).init(self.allocator);
    self.in_flight_fence = ArrayList(c.VkFence).init(self.allocator);

    try self.image_semaphore.resize(MAX_FRAMES);
    try self.render_semaphore.resize(MAX_FRAMES);
    try self.in_flight_fence.resize(MAX_FRAMES);

    var semaphore_info: c.VkSemaphoreCreateInfo = .{};
    semaphore_info.sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

    var fence_info: c.VkFenceCreateInfo = .{};
    fence_info.sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fence_info.flags = c.VK_FENCE_CREATE_SIGNALED_BIT;

    for (0..MAX_FRAMES) |i| {
        if (
            c.vkCreateSemaphore(self.device, &semaphore_info, null, &self.image_semaphore.items[i]) != c.VK_SUCCESS or
                c.vkCreateSemaphore(self.device, &semaphore_info, null, &self.render_semaphore.items[i]) != c.VK_SUCCESS or
                c.vkCreateFence(self.device, &fence_info, null, &self.in_flight_fence.items[i]) != c.VK_SUCCESS) {

            return error.SyncObjectError;
        }
    }
}

fn recreateSwapchain(
    self: *Self,
) !void {
    _ = c.vkDeviceWaitIdle(self.device);

    try self.cleanupSwapchain();

    try self.createSwapchain();
    try self.createImageViews();
    try self.createFramebuffers();
}

fn cleanupSwapchain(
    self: *Self,
) !void {
    for (self.swapchain_images_view.items) |sci| {
        c.vkDestroyImageView(self.device, sci, null);
    }

    for (self.framebuffers.items) |fb| {
        c.vkDestroyFramebuffer(self.device, fb, null);
    }
    c.vkDestroySwapchainKHR(self.device, self.swapchain, null);

    self.swapchain_images_view.deinit();
    self.framebuffers.deinit();
    self.swapchain_images.deinit();

}

fn drawFrame(
    self: *Self,
) !void {
    _ = c.vkWaitForFences(self.device, 1, &self.in_flight_fence.items[self.current_frame], c.VK_TRUE, c.UINT32_MAX);

    _ = c.vkResetFences(self.device, 1, &self.in_flight_fence.items[self.current_frame]);

    var image_idx: u32 = 0;
    _ = c.vkAcquireNextImageKHR(self.device, self.swapchain, c.UINT64_MAX, self.image_semaphore.items[self.current_frame], null, &image_idx);

    _ = c.vkResetCommandBuffer(self.command_buffer.items[self.current_frame], 0);

    try self.recordCommandBuffer(self.command_buffer.items[self.current_frame], image_idx);

    var submit_info: c.VkSubmitInfo = .{};
    submit_info.sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO;

    const wait_semaphores = [_]c.VkSemaphore{self.image_semaphore.items[self.current_frame]};
    const wait_stages = [_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    submit_info.waitSemaphoreCount = 1;
    submit_info.pWaitSemaphores = &wait_semaphores;
    submit_info.pWaitDstStageMask = &wait_stages;

    submit_info.commandBufferCount = 1;
    submit_info.pCommandBuffers = &self.command_buffer.items[self.current_frame];

    const semas =  [_]c.VkSemaphore {self.render_semaphore.items[self.current_frame]};
    submit_info.signalSemaphoreCount = 1;
    submit_info.pSignalSemaphores = &semas;

    //assert(self.present_queue != undefined);
    if (c.vkQueueSubmit(self.present_queue, 1, &submit_info, self.in_flight_fence.items[self.current_frame]) != c.VK_SUCCESS) {
        return error.FailedToSubmitCommandBuffer;
    }

    var present_info: c.VkPresentInfoKHR = .{};
    present_info.sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    present_info.waitSemaphoreCount = 1;
    present_info.pWaitSemaphores = &semas;

    const swapchains = [_]c.VkSwapchainKHR{
        self.swapchain,
    };

    present_info.swapchainCount = 1;
    present_info.pSwapchains = &swapchains;
    present_info.pImageIndices = &image_idx;

    _ = c.vkQueuePresentKHR(self.present_queue, &present_info);

    self.current_frame = (self.current_frame + 1) % MAX_FRAMES;
}

fn recordCommandBuffer(
    self: *Self,
    cmd_buf: c.VkCommandBuffer,
    image_id: u32,
) !void {
    var begin_info: c.VkCommandBufferBeginInfo = .{};
    begin_info.sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begin_info.flags = 0;
    begin_info.pInheritanceInfo = null;

    if (c.vkBeginCommandBuffer(cmd_buf, &begin_info) != c.VK_SUCCESS) {
        return error.CommandBufferFailedToStart;
    }

    var render_info: c.VkRenderPassBeginInfo = .{};
    render_info.sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    render_info.renderPass = self.render_pass;
    render_info.framebuffer = self.framebuffers.items[image_id];
    render_info.renderArea.offset = .{.x = 0, .y = 0};
    render_info.renderArea.extent = self.swapchain_extent;

    const clear_value: c.VkClearValue = .{.color = .{ .float32 = .{0, 0, 0, 0} }};
    render_info.clearValueCount = 1;
    render_info.pClearValues = &clear_value;

    c.vkCmdBeginRenderPass(cmd_buf, &render_info, c.VK_SUBPASS_CONTENTS_INLINE);

    c.vkCmdBindPipeline(cmd_buf, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphics_pipeline);

    const viewport: c.VkViewport = .{
        .width  = @floatFromInt(self.swapchain_extent.width),
        .height = @floatFromInt(self.swapchain_extent.height),
        .minDepth = 0,
        .maxDepth = 1,
        .x = 0,
        .y = 0,
    };

    c.vkCmdSetViewport(cmd_buf,0, 1, &viewport);

    const scissor: c.VkRect2D = .{
        .offset = .{.x = 0, .y = 0},
        .extent = self.swapchain_extent,
    };
    c.vkCmdSetScissor(cmd_buf, 0, 1, &scissor);

    c.vkCmdDraw(cmd_buf, 3, 1, 0, 0);

    c.vkCmdEndRenderPass(cmd_buf);

    if (c.vkEndCommandBuffer(cmd_buf) != c.VK_SUCCESS) {
        return error.FailedToEndCommandBuf;
    }

}

fn createCommandBuffer(
    self: *Self,
) !void {
    self.command_buffer = ArrayList(c.VkCommandBuffer).init(self.allocator);
    try self.command_buffer.resize(MAX_FRAMES);

    var alloc_info: c.VkCommandBufferAllocateInfo = .{};
    alloc_info.sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    alloc_info.commandPool = self.command_pool;
    alloc_info.level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    alloc_info.commandBufferCount = MAX_FRAMES;

    if (c.vkAllocateCommandBuffers(self.device, &alloc_info, self.command_buffer.items.ptr) != c.VK_SUCCESS) {
        return error.CommandBufferNoMemory;
    }
}

fn createCommandPool(
    self: *Self,
) !void {
    const fam_ind = try self.findQueueFamilies(self.physical_device);

    var cmd_create_info: c.VkCommandPoolCreateInfo = .{};
    cmd_create_info.sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    cmd_create_info.queueFamilyIndex = fam_ind.graphics_family.?;
    cmd_create_info.flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;

    if (c.vkCreateCommandPool(self.device, &cmd_create_info, null, &self.command_pool) != c.VK_SUCCESS) {
        return error.FailedToCreateCommandPool;
    }
}

fn createFramebuffers(
    self: *Self,
) !void {
    self.framebuffers = std.ArrayList(c.VkFramebuffer).init(self.allocator);
    try self.framebuffers.resize(self.swapchain_images_view.items.len);
    assert(self.framebuffers.items.len > 0);

    for (0.., self.swapchain_images_view.items) |i, *image| {

        const attachments = [_]c.VkImageView{
            image.*,
        };

        var framebuf_create_info: c.VkFramebufferCreateInfo = .{};
        framebuf_create_info.sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        framebuf_create_info.renderPass = self.render_pass;
        framebuf_create_info.attachmentCount = 1;
        framebuf_create_info.pAttachments = &attachments;
        framebuf_create_info.width = self.swapchain_extent.width;
        framebuf_create_info.height = self.swapchain_extent.height;
        framebuf_create_info.layers = 1;

        assert(self.device != null);
        assert(self.render_pass != null);
        assert(self.framebuffers.items[i] != null);
        if (c.vkCreateFramebuffer(self.device, &framebuf_create_info, null, &self.framebuffers.items[i]) != c.VK_SUCCESS) {
            return error.FailedToCreateFramebuffer;
        }
    }

}

fn createRenderPass(
    self: *Self,
) !void {
    assert(self.swapchain_format != 0);

    var color_attachment: c.VkAttachmentDescription = .{};
    color_attachment.format = self.swapchain_format;
    color_attachment.samples = c.VK_SAMPLE_COUNT_1_BIT;

    color_attachment.loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR;
    color_attachment.storeOp = c.VK_ATTACHMENT_STORE_OP_STORE;

    color_attachment.stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    color_attachment.stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE;
    color_attachment.initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED;
    color_attachment.finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    var color_attachment_ref: c.VkAttachmentReference = .{};
    // Uses the layout format. IE location for within the attachment array.
    color_attachment_ref.attachment = 0;
    color_attachment_ref.layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    var subpass: c.VkSubpassDescription = .{};
    subpass.pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &color_attachment_ref;

    var dep: c.VkSubpassDependency = .{};
    dep.srcSubpass = c.VK_SUBPASS_EXTERNAL;
    dep.dstSubpass = 0;
    dep.srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dep.dstAccessMask = 0;
    dep.dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dep.dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

    var create_info: c.VkRenderPassCreateInfo = .{};
    create_info.sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    create_info.attachmentCount = 1;
    create_info.pAttachments = &color_attachment;
    create_info.subpassCount = 1;
    create_info.pSubpasses = &[_]c.VkSubpassDescription{subpass};
    create_info.dependencyCount = 1;
    create_info.pDependencies = &dep;

    if (c.vkCreateRenderPass(self.device, &create_info, null, &self.render_pass) != c.VK_SUCCESS) {
        return error.FailedToCreateRenderPass;
    }
}

fn createGraphicsPipeline(
    self: *Self,
) !void {
    const vs = try self.loadFile("src/vk/shaders/basicvs.spriv");
    defer self.allocator.free(vs);
    const vs_sm = try self.createShaderModule(vs);
    assert(vs_sm != null);
    defer c.vkDestroyShaderModule(self.device, vs_sm, null);

    const fs = try self.loadFile("src/vk/shaders/basicfs.spriv");
    defer self.allocator.free(fs);
    const fs_sm = try self.createShaderModule(fs);
    defer c.vkDestroyShaderModule(self.device, fs_sm, null);

    var vert_shader_info: c.VkPipelineShaderStageCreateInfo = .{};

    vert_shader_info.sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    vert_shader_info.stage = c.VK_SHADER_STAGE_VERTEX_BIT;
    vert_shader_info.module = vs_sm;
    vert_shader_info.pName = "main";

    var frag_shader_info: c.VkPipelineShaderStageCreateInfo = .{};
    frag_shader_info.sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    frag_shader_info.stage = c.VK_SHADER_STAGE_FRAGMENT_BIT;
    frag_shader_info.module = fs_sm;
    frag_shader_info.pName = "main";

    const shader_stages = [_]c.VkPipelineShaderStageCreateInfo{vert_shader_info, frag_shader_info};

    const dynamic_state_options = [_]c.VkDynamicState{
        c.VK_DYNAMIC_STATE_VIEWPORT,
        c.VK_DYNAMIC_STATE_SCISSOR,
    };

    var dynamic_state: c.VkPipelineDynamicStateCreateInfo = .{};

    dynamic_state.sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    dynamic_state.dynamicStateCount = @intCast(dynamic_state_options.len);
    dynamic_state.pDynamicStates = &dynamic_state_options;

    var vertex_input_info: c.VkPipelineVertexInputStateCreateInfo = .{};
    vertex_input_info.sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    vertex_input_info.vertexBindingDescriptionCount = 0;
    vertex_input_info.pVertexBindingDescriptions = null;
    vertex_input_info.vertexAttributeDescriptionCount = 0;
    vertex_input_info.pVertexAttributeDescriptions = null;

    var input_assembly: c.VkPipelineInputAssemblyStateCreateInfo = .{};
    input_assembly.sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    input_assembly.topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    input_assembly.primitiveRestartEnable = c.VK_FALSE;

    var viewport: c.VkViewport = .{};
    viewport.x = 0.0;
    viewport.y = 0.0;
    viewport.width = @floatFromInt(self.swapchain_extent.width);
    viewport.height = @floatFromInt(self.swapchain_extent.height);
    viewport.minDepth = 0.0;
    viewport.maxDepth = 1.0;

    var scissor: c.VkRect2D = .{};
    scissor.extent = self.swapchain_extent;
    scissor.offset = .{.x = 0, .y = 0};

    var viewport_state: c.VkPipelineViewportStateCreateInfo = .{};
    viewport_state.sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewport_state.viewportCount = 1;
    viewport_state.pViewports = &viewport;
    viewport_state.scissorCount = 1;
    viewport_state.pScissors = &scissor;

    var rasterizer: c. VkPipelineRasterizationStateCreateInfo = .{};
    rasterizer.sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rasterizer.depthClampEnable = c.VK_FALSE;
    rasterizer.rasterizerDiscardEnable = c.VK_FALSE;
    rasterizer.polygonMode = c.VK_POLYGON_MODE_FILL;
    rasterizer.lineWidth = 1.0;
    rasterizer.cullMode = c.VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace = c.VK_FRONT_FACE_CLOCKWISE;
    rasterizer.depthBiasEnable = c.VK_FALSE;
    rasterizer.depthBiasConstantFactor = 0.0;
    rasterizer.depthBiasClamp = 0;
    rasterizer.depthBiasSlopeFactor = 0;

    var multisampling: c.VkPipelineMultisampleStateCreateInfo = .{};
    multisampling.sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisampling.sampleShadingEnable = c.VK_FALSE;
    multisampling.rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT;
    multisampling.minSampleShading = 1.0;


    var color_attachment_state: c.VkPipelineColorBlendAttachmentState = .{};
    color_attachment_state.colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT
        | c.VK_COLOR_COMPONENT_G_BIT
        | c.VK_COLOR_COMPONENT_B_BIT
        | c.VK_COLOR_COMPONENT_A_BIT;
    color_attachment_state.blendEnable = c.VK_FALSE;
    color_attachment_state.srcColorBlendFactor = c.VK_BLEND_FACTOR_ONE;
    color_attachment_state.dstColorBlendFactor = c.VK_BLEND_FACTOR_ZERO;
    color_attachment_state.colorBlendOp = c.VK_BLEND_OP_ADD;

    var color_attachment: c.VkPipelineColorBlendStateCreateInfo = .{};
    color_attachment.sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    color_attachment.logicOp = c.VK_LOGIC_OP_COPY;
    color_attachment.logicOpEnable = c.VK_FALSE;
    color_attachment.attachmentCount = 1;
    color_attachment.pAttachments = &color_attachment_state;
    color_attachment.blendConstants[0] = 0.0;
    color_attachment.blendConstants[1] = 0.0;
    color_attachment.blendConstants[2] = 0.0;
    color_attachment.blendConstants[3] = 0.0;


    var pipeline_layout_create_info: c.VkPipelineLayoutCreateInfo = .{};
    pipeline_layout_create_info.sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;

    if (c.vkCreatePipelineLayout(self.device, &pipeline_layout_create_info, null, &self.pipeline_layout) != c.VK_SUCCESS) {
        return error.PipelineLayoutFailedToCreate;
    }

    var pipeline_create_info: c.VkGraphicsPipelineCreateInfo = .{};
    pipeline_create_info.sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pipeline_create_info.stageCount = 2;
    pipeline_create_info.pStages = &shader_stages;
    pipeline_create_info.pVertexInputState = &vertex_input_info;
    pipeline_create_info.pInputAssemblyState = &input_assembly;
    pipeline_create_info.pViewportState = &viewport_state;
    pipeline_create_info.pRasterizationState = &rasterizer;
    pipeline_create_info.pMultisampleState = &multisampling;
    pipeline_create_info.pColorBlendState = &color_attachment;
    pipeline_create_info.pDynamicState = &dynamic_state;
    pipeline_create_info.layout = self.pipeline_layout;

    pipeline_create_info.renderPass = self.render_pass;
    pipeline_create_info.subpass = 0;

    if (c.vkCreateGraphicsPipelines(self.device, null, 1, &pipeline_create_info, null, &self.graphics_pipeline) != c.VK_SUCCESS) {
        return error.FailedToCreateGraphicsPipeline;
    }

}

fn createShaderModule(
    self: *Self,
    bytes: []const u8,
) !c.VkShaderModule {
    var create_info: c.VkShaderModuleCreateInfo = .{};
    create_info.sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    create_info.codeSize = bytes.len;
    create_info.pCode = @alignCast(@ptrCast(bytes.ptr));

    var shader_module: c.VkShaderModule = undefined;
    if (c.vkCreateShaderModule(self.device, &create_info, null, &shader_module) != c.VK_SUCCESS) {
        return error.FailedToCreateShader;
    }

    return shader_module;
}

fn createSurface(self: *Self) !void {
    if (c.glfwCreateWindowSurface(self.instance, self.window, null, &self.surface) != c.VK_SUCCESS) {
        @panic("Failed to create this thing.");
    }
}

fn createImageViews(
    self: *Self,
) !void {
    self.swapchain_images_view = std.ArrayList(c.VkImageView).init(self.allocator);
    try self.swapchain_images_view.resize(self.swapchain_images.items.len);

    for (0..self.swapchain_images.items.len) |i| {
        var create_info: c.VkImageViewCreateInfo = .{};
        create_info.sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        create_info.image = self.swapchain_images.items[i];
        create_info.viewType = c.VK_IMAGE_TYPE_2D;
        create_info.format = self.swapchain_format;

        create_info.components.r = c.VK_COMPONENT_SWIZZLE_IDENTITY;
        create_info.components.g = c.VK_COMPONENT_SWIZZLE_IDENTITY;
        create_info.components.b = c.VK_COMPONENT_SWIZZLE_IDENTITY;
        create_info.components.a = c.VK_COMPONENT_SWIZZLE_IDENTITY;

        create_info.subresourceRange.aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT;
        create_info.subresourceRange.baseMipLevel = 0;
        create_info.subresourceRange.levelCount = 1;
        create_info.subresourceRange.baseArrayLayer = 0;
        create_info.subresourceRange.layerCount = 1;

        if (c.vkCreateImageView(self.device, &create_info, null, &self.swapchain_images_view.items[i]) != c.VK_SUCCESS) {
            return error.IMAGEDEEZNUTS;
        }
        assert(self.swapchain_images_view.items[i] != null);
    }
}

/// Caller responsible for releasing memory
fn loadFile(
    self: *Self,
    path: []const u8,
) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const buf = try file.readToEndAlloc(self.allocator, 10_000_000);

    return buf;
}

fn createSwapchain(
    self: *Self,
) !void {
    self.swapchain_images = std.ArrayList(c.VkImage).init(self.allocator);
    var swapchain_deets = try querySwapchainSupport(self, self.physical_device);
    defer swapchain_deets.deinit();

    const format = swapchain_deets.chooseSwapchain();
    const extent = swapchain_deets.chooseSwapExtent(self.window);
    const present_mode = swapchain_deets.chooseSwapPresentMode();

    var image_count = swapchain_deets.capabilities.minImageCount + 1;

    if (swapchain_deets.capabilities.maxImageCount > 0 and image_count > swapchain_deets.capabilities.maxImageCount) {
        image_count = swapchain_deets.capabilities.maxImageCount;
    }

    var create_info: c.VkSwapchainCreateInfoKHR = .{
        .sType =  c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = self.surface,
        .imageExtent = extent,
        .minImageCount = image_count,
        .imageFormat = format.format,
        .imageColorSpace = format.colorSpace,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .presentMode = present_mode,
    };

    const indices = try self.findQueueFamilies(self.physical_device);
    if (indices.graphics_family.? != indices.present_family.?) {
        create_info.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
        create_info.queueFamilyIndexCount = 2;
        create_info.pQueueFamilyIndices = &[_]u32{indices.graphics_family.?, indices.present_family.?};
    } else {
        create_info.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
        create_info.queueFamilyIndexCount = 1;
        create_info.pQueueFamilyIndices = &[_]u32{indices.graphics_family.? };
    }

    create_info.preTransform = swapchain_deets.capabilities.currentTransform;
    create_info.compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    create_info.clipped = c.VK_TRUE;
    create_info.oldSwapchain = null;

    if (c.vkCreateSwapchainKHR(self.device, &create_info, null, &self.swapchain) != c.VK_SUCCESS) {
        return error.ThisHoeCantGetASwapchain;
    }

    _ = c.vkGetSwapchainImagesKHR(self.device, self.swapchain, &image_count, null);
    try self.swapchain_images.resize(image_count);
    _ = c.vkGetSwapchainImagesKHR(self.device, self.swapchain, &image_count, self.swapchain_images.items.ptr);

    self.swapchain_format = format.format;
    self.swapchain_extent = extent;
}

fn querySwapchainSupport(
    self: *Self,
    device: c.VkPhysicalDevice
) !SwapchainDetails {

    var details: SwapchainDetails = undefined;
    details.init(self.allocator);

    _ = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, self.surface, &details.capabilities);

    var format_count: u32 = 0;
    _ = c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &format_count, null);
    if (format_count != 0) {
        try details.formats.resize(format_count);
        _ = c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &format_count, details.formats.items.ptr);
    }

    var present_count: u32 = 0;
    _ = c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, self.surface, &present_count, null);
    if (present_count != 0) {
        try details.present_modes.resize(format_count);
        _ = c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, self.surface, &present_count, details.present_modes.items.ptr);
    }

    return details;
}


/// DEVICE SETUP

fn createLogicalDevice(self: *Self) !void {
    const indices = try self.findQueueFamilies(self.physical_device);

    var families = std.ArrayList(u32).init(self.allocator);
    defer families.deinit();

    const graphf = indices.graphics_family.?;
    try families.append(graphf);

    if (indices.present_family) |g| {
        if (g != graphf) {
            try families.append(g);
        }
    }

    var queue_list = std.ArrayList(c.VkDeviceQueueCreateInfo).init(self.allocator);
    defer queue_list.deinit();

    var queue_priority: f32 = 1.0;
    for (families.items) |i| {
        var queue_create_info: c.VkDeviceQueueCreateInfo = .{};
        queue_create_info.sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queue_create_info.queueFamilyIndex = @intCast(i);
        queue_create_info.queueCount = 1;
        queue_create_info.pQueuePriorities = &queue_priority;

        try queue_list.append(queue_create_info);
    }

    var device_features: c.VkPhysicalDeviceFeatures = .{};

    var create_info: c.VkDeviceCreateInfo = .{};
    create_info.sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    create_info.queueCreateInfoCount = @intCast(queue_list.items.len);
    create_info.pQueueCreateInfos = queue_list.items.ptr;

    create_info.pEnabledFeatures = &device_features;
    create_info.enabledExtensionCount = @intCast(required_mac_support.len);
    create_info.ppEnabledExtensionNames = required_mac_support.ptr;

    if (enableValidationLayers) {
        create_info.enabledLayerCount = validationLayers.len;
        create_info.ppEnabledLayerNames = validationLayers.ptr;
    } else {
        create_info.enabledLayerCount = 0;
    }

    if (c.vkCreateDevice(self.physical_device, &create_info, null, &self.device) != c.VK_SUCCESS) {
        return error.FailedToCreateDevice;
    }

    if (indices.graphics_family) |gf| {
        c.vkGetDeviceQueue(self.device, gf, 0, &self.graphics_queue);
    }
    if (indices.present_family) |pf| {
        c.vkGetDeviceQueue(self.device, pf, 0, &self.present_queue);
    }
}

fn pickPhysicalDevice(self: *Self) !void {
    var device_count: u32 = 0;
    _ = c.vkEnumeratePhysicalDevices(self.instance, &device_count, null);

    if (device_count == 0) {
        return error.FailedToFindGPU;
    }

    const devices = try self.allocator.alloc(c.VkPhysicalDevice, device_count);
    defer self.allocator.free(devices);
    _ = c.vkEnumeratePhysicalDevices(self.instance, &device_count, devices.ptr);

    for (devices) |dev| {
        if (try self.isDeviceSuitable(dev)) {
            self.physical_device = dev;
            break;
        }
    }

    if (self.physical_device == null) {
        return error.FailedToFindSuitableGPU;
    }
}

fn isDeviceSuitable(self: *Self, device: c.VkPhysicalDevice) !bool {
    var device_properties: c.VkPhysicalDeviceProperties = .{};
    var device_features: c.VkPhysicalDeviceFeatures = .{};
    c.vkGetPhysicalDeviceProperties(device, &device_properties);
    c.vkGetPhysicalDeviceFeatures(device, &device_features);

    var available_extensions_count: u32 = 0;
    _ = c.vkEnumerateDeviceExtensionProperties(device, null, &available_extensions_count, null);
    const available = try self.allocator.alloc(c.VkExtensionProperties, available_extensions_count);
    defer self.allocator.free(available);
    _ = c.vkEnumerateDeviceExtensionProperties(device, null, &available_extensions_count, @ptrCast(available));

    var contains_swapchain: bool = false;
    swapchain: for (0..available_extensions_count) |i| {
        const ext_name: []const u8 = available[i].extensionName[0..std.mem.indexOf(u8, available[i].extensionName[0..], &[_]u8{0}).?];
        if (std.mem.eql(u8, "VK_KHR_swapchain", ext_name)) {
            contains_swapchain = true;
            break :swapchain;
        }
    }

    var swapchain_suitible = false;
    if (contains_swapchain) {
        var swapchain_deets = try self.querySwapchainSupport(device);
        defer swapchain_deets.deinit();

        swapchain_suitible = (swapchain_deets.formats.items.len != 0 and swapchain_deets.present_modes.items.len != 0);

    }


    return contains_swapchain and swapchain_suitible;
    //const indices = try self.findQueueFamilies(device);

    //return indices.graphics_family != null;
    //_ = self;
    //return device_properties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU and device_features.geometryShader == 0;
}

fn findQueueFamilies(self: *Self, device: c.VkPhysicalDevice) !QueueFamilyIndices {
    var indices: QueueFamilyIndices = .{};
    _ = &indices;


    var queue_family_count: u32 = 0;
    _ = c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

    const queue_families = try self.allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
    defer self.allocator.free(queue_families);
    _ = c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);

    for (0..queue_family_count) |i| {
        const fam = queue_families[i];

        if (fam.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
            indices.graphics_family = @intCast(i);
        }

        var present_support: c.VkBool32 = 0;
        _ = c.vkGetPhysicalDeviceSurfaceSupportKHR(self.physical_device, @intCast(i), self.surface, &present_support);
        if (present_support == 1) {
            indices.present_family = @intCast(i);
        }

        if (indices.isComplete()) {
            break;
        }
    }

    return indices;
}

/// VALIDATION/DEBUG

fn debugCallback(
    message_severity : c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    message_type     : c.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data    : [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
    user_data        : ?*anyopaque,
) callconv(.c) c.VkBool32 {
    _ = message_type;
    _ = user_data;
    if (message_severity != 1) {
        std.log.err("{s}\n", .{callback_data.*.pMessage});
    }

    return c.VK_FALSE;
}

fn populateDebugMessengerCreateInfo(
    create_info: [*c]c.VkDebugUtilsMessengerCreateInfoEXT
) void {
    create_info.* = .{};
    create_info.*.sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
    create_info.*.messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
    create_info.*.messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
    create_info.*.pfnUserCallback = debugCallback;
    create_info.*.pUserData = null;
}

fn setupDebugMessages(self: *Self) !void {

    if (!enableValidationLayers) return;
    var create_info: c.VkDebugUtilsMessengerCreateInfoEXT = .{};

    populateDebugMessengerCreateInfo(&create_info);

    if (self.createDebugMessageUtilsMessengerEXT(
        &create_info,
        null,
        self.debug_message,
        ) != c.VK_SUCCESS) {
        return error.FailedMessengerSetup;
    }
}

fn destroyDebugMessageUtilsMessengerEXT(
    self: *Self,
    debug_message: c.VkDebugUtilsMessengerEXT,
    allocator: [*c]const c.VkAllocationCallbacks,
) void {

    const func: c.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(self.instance, "vkDestroyDebugUtilsMessengerEXT"));

    if (func) |f| {
        f(self.instance, debug_message, allocator);
    } else {
        @panic("This is failing to destroy messages. Couldnt fine function");
    }

}
fn createDebugMessageUtilsMessengerEXT(
    self: *Self,
    create_info: [*c]const c.VkDebugUtilsMessengerCreateInfoEXT,
    allocator: [*c]const c.VkAllocationCallbacks,
    debug_message: c.VkDebugUtilsMessengerEXT,
) c.VkResult {
    const func: c.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(
        self.instance,
        "vkCreateDebugUtilsMessengerEXT",
    ));
    if (func) |f| {
        return f(self.instance, create_info, allocator, @constCast(&debug_message));
    } else {
        return c.VK_ERROR_EXTENSION_NOT_PRESENT;
    }
}
fn checkValidationSuport(a: std.mem.Allocator) !bool {
    var extension_count: u32 = undefined;
    _ = c.vkEnumerateInstanceLayerProperties(&extension_count, null);

    const available = try a.alloc(c.VkLayerProperties, extension_count);
    _ = c.vkEnumerateInstanceLayerProperties(&extension_count, available.ptr);

    for (validationLayers) |vl| {
        var layer_found = false;
        inner: for (available) |ex| {
            if (std.mem.eql(
                u8,
                ex.layerName[0..std.mem.indexOfScalar(u8, &ex.layerName, 0).?],
                std.mem.span(vl),
            )) {
                layer_found = true;
                break :inner;
            }
        }

        if (!layer_found) {
            return false;
        }
    }
    return true;
}

///  INSTANCE

fn createInstance(self: *Self) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    defer {
        _ = gpa.deinit();
    }
    var appInfo: c.VkApplicationInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Vulkan",
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "no Engine",
        .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
    };

    var createInfo: c.VkInstanceCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
    };

    var requiredExtensions = std.ArrayList([*c]const u8).init(allocator);
    defer requiredExtensions.deinit();
    var glfw_extension_count: u32 = 0;
    const glfw_extensions: [*c][*c]const u8 = c.glfwGetRequiredInstanceExtensions(&glfw_extension_count);


    try requiredExtensions.appendSlice(glfw_extensions[0..glfw_extension_count]);

    try requiredExtensions.append(c.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME);
    try requiredExtensions.append(c.VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME);

    if (enableValidationLayers) {
        try requiredExtensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
    }

    createInfo.flags |= c.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;

    createInfo.enabledExtensionCount = @intCast(requiredExtensions.items.len);
    createInfo.ppEnabledExtensionNames = @ptrCast(requiredExtensions.items);

    if (enableValidationLayers and !(try checkValidationSuport(a))) {
        return error.ValidationLayersNotAvailable;
    }

    var debug_create_info: c.VkDebugUtilsMessengerCreateInfoEXT = .{};
    if (enableValidationLayers) {
        createInfo.enabledLayerCount = validationLayers.len;
        createInfo.ppEnabledLayerNames = validationLayers.ptr;
        populateDebugMessengerCreateInfo(&debug_create_info);
        createInfo.pNext = @ptrCast(&debug_create_info);
    } else {
        createInfo.enabledLayerCount = 0;
    }

    const result = c.vkCreateInstance(&createInfo, null, &self.instance);
    if (result != c.VK_SUCCESS) {
        std.log.err("Error: {}", .{result});
    }

}
fn initWindow(self: *Self) !void {
    _ = c.glfwInit();
    _ = c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    _ = c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_TRUE);
    self.window = c.glfwCreateWindow(self.width, self.height, "Vulkan", null, null);
}

fn mainLoop(self: *Self) !void {
    while (c.glfwWindowShouldClose(self.window) != 1) {
        c.glfwPollEvents();
        try self.drawFrame();
    }
}

fn cleanup(self: *Self) !void {
    _ = c.vkDeviceWaitIdle(self.device);
    try self.cleanupSwapchain();

    for (0..self.current_frame) |i| {
        c.vkDestroySemaphore(self.device, self.image_semaphore.items[i], null);
        c.vkDestroySemaphore(self.device, self.render_semaphore.items[i], null);
        c.vkDestroyFence(self.device, self.in_flight_fence.items[i], null);
    }
    self.image_semaphore.deinit();
    self.render_semaphore.deinit();
    self.in_flight_fence.deinit();

    c.vkDestroyCommandPool(self.device, self.command_pool, null);


    c.vkDestroyPipeline(self.device, self.graphics_pipeline, null);
    c.vkDestroyRenderPass(self.device, self.render_pass, null);
    c.vkDestroyPipelineLayout(self.device, self.pipeline_layout, null);

    c.vkDestroySurfaceKHR(self.instance, self.surface, null);
    c.vkDestroyDevice(self.device, null);


    if (enableValidationLayers) {
        self.destroyDebugMessageUtilsMessengerEXT(self.debug_message, null);
    }
    self.command_buffer.deinit();

    c.vkDestroyInstance(self.instance, null);
    c.glfwDestroyWindow(self.window);
    c.glfwTerminate();

    _ = self.gpa.deinit();
}
