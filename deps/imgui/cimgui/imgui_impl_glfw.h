// dear imgui: Platform Backend for GLFW
// This needs to be used along with a Renderer (e.g. OpenGL3, Vulkan, WebGPU..)
// (Info: GLFW is a cross-platform general purpose library for handling windows, inputs, OpenGL/Vulkan graphics context creation, etc.)

// Implemented features:
//  [X] Platform: Clipboard support.
//  [X] Platform: Gamepad support. Enable with 'io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad'.
//  [x] Platform: Mouse cursor shape and visibility. Disable with 'io.ConfigFlags |= ImGuiConfigFlags_NoMouseCursorChange'. FIXME: 3 cursors types are missing from GLFW.
//  [X] Platform: Keyboard arrays indexed using GLFW_KEY_* codes, e.g. ImGui::IsKeyPressed(GLFW_KEY_SPACE).

// You can use unmodified imgui_impl_* files in your project. See examples/ folder for examples of using this.
// Prefer including the entire imgui/ repository into your project (either as a copy or as a submodule), and only build the backends you need.
// If you are new to Dear ImGui, read documentation from the docs/ folder + read the top of imgui.cpp.
// Read online: https://github.com/ocornut/imgui/tree/master/docs

// About GLSL version:
// The 'glsl_version' initialization parameter defaults to "#version 150" if NULL.
// Only override if your GL version doesn't handle this GLSL version. Keep NULL if unsure!

#ifndef IMGUI_IMPL_GLFW_H
#define IMGUI_IMPL_GLFW_H

typedef struct GLFWwindow GLFWwindow;
typedef struct GLFWmonitor GLFWmonitor;

#if defined(__cplusplus)
extern "C"
{
#endif

bool     ImGui_ImplGlfw_InitForOpenGL(GLFWwindow* window, bool install_callbacks);
bool     ImGui_ImplGlfw_InitForVulkan(GLFWwindow* window, bool install_callbacks);
bool     ImGui_ImplGlfw_InitForOther(GLFWwindow* window, bool install_callbacks);
void     ImGui_ImplGlfw_Shutdown();
void     ImGui_ImplGlfw_NewFrame();

// GLFW callbacks
// - When calling Init with 'install_callbacks=true': GLFW callbacks will be installed for you. They will call user's previously installed callbacks, if any.
// - When calling Init with 'install_callbacks=false': GLFW callbacks won't be installed. You will need to call those function yourself from your own GLFW callbacks.
void     ImGui_ImplGlfw_WindowFocusCallback(GLFWwindow* window, int focused);
void     ImGui_ImplGlfw_CursorEnterCallback(GLFWwindow* window, int entered);
void     ImGui_ImplGlfw_MouseButtonCallback(GLFWwindow* window, int button, int action, int mods);
void     ImGui_ImplGlfw_ScrollCallback(GLFWwindow* window, double xoffset, double yoffset);
void     ImGui_ImplGlfw_KeyCallback(GLFWwindow* window, int key, int scancode, int action, int mods);
void     ImGui_ImplGlfw_CharCallback(GLFWwindow* window, unsigned int c);
void     ImGui_ImplGlfw_MonitorCallback(GLFWmonitor* monitor, int event);

#if defined(__cplusplus)
}
#endif

#endif
