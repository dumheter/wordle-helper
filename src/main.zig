const std = @import("std");
const glfw = @import("glfw");
const zui = @import("zimgui");
const zgl = @import("zimgui_backend").OpenGl3;
const zglfw = @import("zimgui_backend").Glfw;

// https://github.com/dwyl/english-words/
const words_raw = @embedFile("res/wordlist.txt");

// swedish word list https://github.com/martinlindhe/wordlist_swedish

pub fn main() !void {
    std.debug.print("-*- wordle helper -*-\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var words = try std.ArrayList([kMaxWordLen + 1]u8).initCapacity(allocator, 10000);
    var word_length: i32 = 5;
    try gatherWords(@intCast(usize, word_length), words_raw, &words);
    defer words.deinit();

    var filtered_words = try words.clone();
    defer filtered_words.deinit();

    var rasterized_words = std.ArrayList(u8).init(allocator);
    try rasterizeWords(filtered_words, &rasterized_words);
    defer rasterized_words.deinit();

    var filter = Filter.init();

    ///////////////////////////////////////////////////////////////////////////////
    // setup glfw & imgui

    const display_size = zui.Vec2{
        .x = 480,
        .y = 720,
    };

    var window: glfw.Window = undefined;
    var ctx: zui.Context = undefined;
    var io: zui.Io = undefined;
    {
        _ = glfw.init(glfw.InitHints{});

        glfw.setErrorCallback(glfwErrorCallback);

        window = glfw.Window.create(
            @floatToInt(u32, display_size.x),
            @floatToInt(u32, display_size.y),
            "zig imgui template",
            null,
            null,
            glfw.Window.Hints{
                .context_version_major = 4,
                .context_version_minor = 5,
                .opengl_profile = .opengl_core_profile,
        }) orelse unreachable;

        glfw.makeContextCurrent(window);
        glfw.swapInterval(1); // vsync

        if (zgl.gladLoadGLLoader(glfw.getProcAddress) == 0) {
            std.debug.panic("Could not pass glad the loader function.\n", .{});
        }

        zui.init();
        ctx = zui.getCurrentContext() orelse unreachable;

        zui.setImguiTheme();

        if (!zglfw.initForOpenGL(window.handle, true)) {
            std.debug.panic("Failed to init glfw for OpenGL.", .{});
        }

        const glsl_version = "#version 450";
        if (!zgl.init(glsl_version)) {
            std.debug.panic("Failed to init OpenGL3.", .{});
        }

        io = ctx.getIo();
        var font_atlas = io.getFontAtlas();

        _ = font_atlas.addFontFromFileTTF("src/res/font/CascadiaMonoPL.ttf", 15.0);
        if (!font_atlas.build()) {
            std.debug.print("Failed to build fonts.", .{});
        }

        io.setDisplaySize(display_size);

        zgl.enable(zgl.DEBUG_OUTPUT) catch {};
        var not_user_param: usize = undefined;
        zgl.debugMessageCallback(onOpenGl3DebugMessage, @ptrCast(*const anyopaque, &not_user_param));
    }

    ///////////////////////////////////////////////////////////////////////////////
    // run loop
    var run: bool = true;
    while (run) {
        if (glfw.pollEvents()) {} else |err| {
            std.debug.panic("failed to poll events: {}", .{err});
        }

        // escape can exit the program
        var action: glfw.Action = window.getKey(glfw.Key.escape);
        if (action == glfw.Action.press or window.shouldClose()) {
            run = false;
        }

        zgl.newFrame();
        zglfw.newFrame();
        zui.newFrame();

        ///////////////////////////////////////////////////////////////////////////////
        // YOUR CODE GOES HERE

        {
            zui.setNextWindowPos(zui.Vec2{ .x = 0, .y = 0 }, .Always, zui.Vec2{ .x = 0, .y = 0 });
            const wsize = window.getSize();
            const size = zui.Vec2{ .x = @intToFloat(f32, wsize.width), .y = @intToFloat(f32, wsize.height) };
            zui.setNextWindowSize(size, .Always);
            _ = zui.begin("main-window", null, zui.WindowFlags.NoDecoration);

            if (zui.sliderInt("word length", .{}, &word_length, 1, kMaxWordLen)) {
                // user moved slider, recompute the list of words
                try gatherWords(@intCast(usize, word_length), words_raw, &words);
                try filterWords(words, &filtered_words, filter);
                try rasterizeWords(filtered_words, &rasterized_words);
            }

            zui.pushStyleColor(.Text, zui.ColorSolarized.rgbagreen);
            if (zui.inputTextWithHint("green letters", .{}, "> list green letters", .{}, filter.green_letters[0..@intCast(usize, word_length) + 1], .CharsUppercase)) {
                // user entered a filter, filter the words!
                try filterWords(words, &filtered_words, filter);
                try rasterizeWords(filtered_words, &rasterized_words);
            }
            zui.popStyleColor(1);

            zui.pushStyleColor(.Text, zui.ColorSolarized.rgbayellow);
            if (zui.inputTextWithHint("yellow letters", .{}, "> list yellow letters", .{}, filter.yellow_letters[0..@intCast(usize, word_length) + 1], .CharsUppercase)) {
                // user entered a filter, filter the words!
                try filterWords(words, &filtered_words, filter);
                try rasterizeWords(filtered_words, &rasterized_words);
            }
            zui.popStyleColor(1);

            zui.pushStyleColor(.Text, zui.ColorSolarized.rgbabase00);
            if (zui.inputTextWithHint("gray letters", .{}, "> list gray letters", .{}, filter.gray_letters[0..filter.gray_letters.len], .CharsUppercase)) {
                // user entered a filter, filter the words!
                try filterWords(words, &filtered_words, filter);
                try rasterizeWords(filtered_words, &rasterized_words);
            }
            zui.popStyleColor(1);

            zui.separator();
            zui.text("Found {} words.", .{filtered_words.items.len});

            zui.separator();
            zui.text("{s}", .{rasterized_words.items[0..rasterized_words.items.len - 1]});

            zui.end();
        }

        ///////////////////////////////////////////////////////////////////////////////

        zui.render();

        const size = window.getFramebufferSize();
        try zgl.viewport(0, 0, @intCast(i32, size.width), @intCast(i32, size.height));
        zgl.clearColor(0.9, 0.9, 0.9, 0);
        try zgl.clear(zgl.COLOR_BUFFER_BIT);
        zgl.renderDrawData(zui.getDrawData() orelse unreachable);


        if (window.swapBuffers()) {} else |err| {
            std.debug.panic("failed to swap buffers: {}", .{err});
        }
    }

    // cleanup
    zui.deinit();
    window.destroy();
    glfw.terminate();
}

const kMaxWordLen: usize = 6;
fn gatherWords(word_len: usize, input: [:0]const u8, words: *std.ArrayList([kMaxWordLen + 1]u8)) !void {
    std.debug.assert(word_len <= kMaxWordLen);
    words.clearRetainingCapacity();

    var iter = std.mem.split(u8, input, "\n");
    while (iter.next()) |line| {
        if (line.len > 0) {
            var adjust: usize = if (line[line.len - 1] == 13) 1 else 0;
            if (line.len == word_len + adjust) {
                var buf: [kMaxWordLen + 1]u8 = [_]u8{' '} ** (kMaxWordLen + 1);
                buf[kMaxWordLen] = '\n';
                for (line[0 .. line.len - adjust]) |l, i| {
                    buf[i] = l;
                }
                try words.append(buf);
            }
        }
    }
}

fn filterWords(words: std.ArrayList([kMaxWordLen + 1]u8), filtered_words: *std.ArrayList([kMaxWordLen + 1]u8), filter: Filter) !void {
    filtered_words.clearRetainingCapacity();
    try filtered_words.ensureTotalCapacity(words.items.len);

    for (words.items) |word| {
        var pass = true;

        // green
        for (word) |w, i| {
            if (filter.green_letters[i] == 0) break;
            if (filter.green_letters[i] != ' ' and (filter.green_letters[i] != w and filter.green_letters[i] + 32 != w)) {
                pass = false;
                break;
            }
        }

        // gray
        for (word) |w| {
            for (filter.gray_letters) |g| {
                if (g == 0) break;
                if (g == w or g + 32 == w) {
                    pass = false;
                    break;
                }
            }
        }

        // yellow
        for (filter.yellow_letters) |y| {
            if (y == 0) break;

            var yellow_found = false;
            for (word) |w| {
                if (y == w or y + 32 == w) {
                    yellow_found = true;
                    break;
                }
            }
            if (!yellow_found) {
                pass = false;
                break;
            }
        }

        if (pass) {
            filtered_words.appendAssumeCapacity(word);
        }
    }
}

fn rasterizeWords(words: std.ArrayList([kMaxWordLen + 1]u8), rasterized_words: *std.ArrayList(u8)) !void {
    rasterized_words.clearRetainingCapacity();
    try rasterized_words.ensureTotalCapacity((kMaxWordLen + 1) * words.items.len + 1);

    for (words.items) |word| {
        rasterized_words.appendSliceAssumeCapacity(word[0..word.len]);
    }
    rasterized_words.appendAssumeCapacity(0);
}

const Filter = struct {
    green_letters: [kMaxWordLen + 1]u8,
    yellow_letters: [kMaxWordLen + 1]u8,
    gray_letters: [30]u8,

    pub fn init() Filter {
        var filter = Filter{ .green_letters = undefined, .gray_letters = undefined, .yellow_letters = undefined };
        filter.green_letters = [_]u8{0} ** filter.green_letters.len;
        filter.yellow_letters = [_]u8{0} ** filter.yellow_letters.len;
        filter.gray_letters = [_]u8{0} ** filter.gray_letters.len;
        return filter;
    }
};

///////////////////////////////////////////////////////////////////////////////
// See debug messages from glfw and opengl

fn glfwErrorCallback(error_code: glfw.ErrorCode, msg: [:0]const u8) void {
    std.debug.print("glfw error {}: {s}\n", .{error_code, msg});
}

fn onOpenGl3DebugMessage(source: zgl.ValueType, type_: zgl.ValueType, id: u32, severity: zgl.ValueType, length: i32, message: [*c]const u8, user_param: *const anyopaque) void {
    _ = user_param;
    var msg = message[0..@intCast(usize, length)];
    std.debug.print("OpenGL3: {{id: {}, severity: {}, message: {s}, source: {}, type: {}}}\n", .{id, severity, msg, source, type_});
}
