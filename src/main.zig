const std = @import("std");
const c = @import("c.zig").c;
const glfw = @import("glfw");
const theme = @import("theme.zig");

// https://github.com/dwyl/english-words/
const words_raw = @embedFile("../res/wordlist.txt");

pub fn main() !void {
    std.debug.print("-*- wordle helper -*-\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var words = try std.ArrayList([kMaxWordLen+1]u8).initCapacity(allocator, 10000);
    var word_length: c_int = 5;
    try gatherWords(@intCast(usize, word_length), words_raw, &words);
    defer words.deinit();

    var filtered_words = try words.clone();
    defer filtered_words.deinit();

    var rasterized_words = std.ArrayList(u8).init(allocator);
    try rasterizeWords(filtered_words, &rasterized_words);
    defer rasterized_words.deinit();

    var filter = Filter.init();

    var font: *c.ImFont = undefined;
    var run: bool = true;

    var display_size = c.ImVec2{
        .x = 380,
        .y = 720,
    };

    // setup glfw & imgui
    var window: glfw.Window = undefined;
    var context: *c.ImGuiContext = undefined;
    var io: *c.ImGuiIO = undefined;
    {
        try glfw.init(glfw.InitHints{});

        window = try glfw.Window.create(
            @floatToInt(u32, display_size.x),
            @floatToInt(u32, display_size.y),
            "wordle helper",
            null,
            null,
            glfw.Window.Hints{
                .context_version_major = 3,
                .context_version_minor = 0,
        });

        try glfw.makeContextCurrent(window);
        try glfw.swapInterval(1); // vsync

        std.debug.print("imgui version: {s}\n", .{c.igGetVersion()});
        context = c.igCreateContext(null);

        theme.setImguiTheme(&c.igGetStyle().*.Colors);

        if (!c.ImGui_ImplGlfw_InitForOpenGL(@ptrCast(*c.GLFWwindow, window.handle), true)) {
            std.debug.panic("", .{});
        }

        const glsl_version = "#version 130";
        if (!c.ImGui_ImplOpenGL3_Init(glsl_version)) {
            std.debug.panic("could not init opengl", .{});
        }

        io = c.igGetIO();
        var text_pixels: [*c]u8 = undefined;
        var text_w: i32 = undefined;
        var text_h: i32 = undefined;
        c.ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &text_pixels, &text_w, &text_h, null);
        font = c.ImFontAtlas_AddFontFromFileTTF(io.Fonts, "res/font/CascadiaMonoPL.ttf", 15.0, null, c.ImFontAtlas_GetGlyphRangesDefault(io.Fonts));
        _ = c.ImFontAtlas_Build(io.Fonts);

        io.DisplaySize = display_size;
        io.DeltaTime = 1.0 / 60.0;
    }

    // run loop
    var show_demo_window = false;
    while (run) {
        if (glfw.pollEvents()) {} else |err| {
            std.debug.panic("failed to poll events: {}", .{err});
        }

        // escape can exit the program
        var action: glfw.Action = window.getKey(glfw.Key.escape);
        if (action == glfw.Action.press or window.shouldClose()) {
            run = false;
        }

        c.ImGui_ImplOpenGL3_NewFrame();
        c.ImGui_ImplGlfw_NewFrame();
        c.igNewFrame();
        c.igPushFont(font);

        ///////////////////////////////////////////////////////////////////////////////
        // YOUR CODE GOES HERE

        {
            var flags: c.ImGuiWindowFlags = c.ImGuiWindowFlags_NoTitleBar;
            flags |= c.ImGuiWindowFlags_NoMove;
            flags |= c.ImGuiWindowFlags_NoResize;
            flags |= c.ImGuiWindowFlags_NoCollapse;
            c.igSetNextWindowPos(c.ImVec2{ .x = 0, .y = 0 }, c.ImGuiCond_Always, c.ImVec2{ .x = 0, .y = 0 });
            const wsize = try window.getSize();
            const size = c.ImVec2{ .x = @intToFloat(f32, wsize.width), .y = @intToFloat(f32, wsize.height) };
            c.igSetNextWindowSize(size, c.ImGuiCond_Always);
            _ = c.igBegin("main-window", null, flags);

            //var text_size: c.ImVec2 = undefined;
            //c.igCalcTextSize(&text_size, "toggle imgui demo", null, true, 1000.0);
            //if (c.igButton("toggle imgui demo", c.ImVec2{.x = text_size.x + 8, .y = text_size.y + 8})) {
            //    show_demo_window = !show_demo_window;
            //}

            if (c.igSliderInt("word length", &word_length, 1, kMaxWordLen, null, 0)) {
                // user moved slider, recompute the list of words
                try gatherWords(@intCast(usize, word_length), words_raw, &words);
                try filterWords(words, &filtered_words, filter);
                try rasterizeWords(filtered_words, &rasterized_words);
            }

            c.igPushStyleColor_Vec4(c.ImGuiCol_Text, theme.green);
            if (c.igInputTextWithHint(
                "green letters",
                "> space to skip",
                @ptrCast([*c]u8, filter.green_letters[0..]),
                @intCast(usize, word_length+1),
                c.ImGuiInputTextFlags_CharsUppercase,
                null,
                null
            )) {
                // user entered a filter, filter the words!
                try filterWords(words, &filtered_words, filter);
                try rasterizeWords(filtered_words, &rasterized_words);
            }
            c.igPopStyleColor(1);

            c.igPushStyleColor_Vec4(c.ImGuiCol_Text, theme.base00);
            if (c.igInputTextWithHint(
                "gray letters",
                "> list gray letters",
                @ptrCast([*c]u8, filter.gray_letters[0..]),
                @intCast(usize, filter.gray_letters.len),
                c.ImGuiInputTextFlags_CharsUppercase,
                null,
                null
            )) {
                // user entered a filter, filter the words!
                try filterWords(words, &filtered_words, filter);
                try rasterizeWords(filtered_words, &rasterized_words);
            }
            c.igPopStyleColor(1);

            c.igSeparator();
            c.igText("Found %i words.", filtered_words.items.len);

            c.igSeparator();
            c.igTextUnformatted(
                @ptrCast([*c]const u8, rasterized_words.items),
                @ptrCast([*c]const u8, &rasterized_words.items[rasterized_words.items.len-1])
            );

            c.igEnd();
        }

        // draw imgui's demo window
        if (show_demo_window) {
            c.igShowDemoWindow(&show_demo_window);
        }

        ///////////////////////////////////////////////////////////////////////////////

        c.igPopFont();
        c.igRender();

        if (window.getFramebufferSize()) |size| {
            c.glViewport(0, 0, @intCast(c_int, size.width), @intCast(c_int, size.height));
            c.glClearColor(0.9, 0.9, 0.9, 0);
            c.glClear(c.GL_COLOR_BUFFER_BIT);
            c.ImGui_ImplOpenGL3_RenderDrawData(c.igGetDrawData());
        } else |err| {
            std.debug.panic("failed to get frame buffer size: {}", .{err});
        }

        if (window.swapBuffers()) {} else |err| {
            std.debug.panic("failed to swap buffers: {}", .{err});
        }
    }

    // cleanup
    c.igDestroyContext(context);
    window.destroy();
    glfw.terminate();
}

const kMaxWordLen: usize = 6;
fn gatherWords(word_len: usize, input: [:0]const u8, words: *std.ArrayList([kMaxWordLen+1]u8)) !void {
    std.debug.assert(word_len <= kMaxWordLen);
    words.clearRetainingCapacity();

    var iter = std.mem.split(u8, input, "\n");
    while (iter.next()) |line| {
        if (line.len > 0) {
            var adjust: usize = if (line[line.len-1] == 13) 1 else 0;
            if (line.len == word_len + adjust) {
                var buf: [kMaxWordLen+1]u8 = [_]u8{' '} ** (kMaxWordLen+1);
                buf[kMaxWordLen] = '\n';
                for (line[0..line.len-adjust]) |l, i| { buf[i] = l; }
                try words.append(buf);
            }
        }
    }
}

fn filterWords(words: std.ArrayList([kMaxWordLen+1]u8), filtered_words: *std.ArrayList([kMaxWordLen+1]u8), filter: Filter) !void {
    filtered_words.clearRetainingCapacity();
    try filtered_words.ensureTotalCapacity(words.items.len);

    for (words.items) |word| {
        var pass = true;
        for (word) |w, i| {
            if (filter.green_letters[i] == 0) break;
            if (filter.green_letters[i] != ' '
                    and (filter.green_letters[i] != w
                             and filter.green_letters[i] + 32 != w)) {
                pass = false;
                break;
            }
        }

        for (word) |w| {
            for (filter.gray_letters) |g| {
                if (g == 0) break;
                if (g == w or g +32 == w) {
                    pass = false;
                    break;
                }
            }
        }

        if (pass) {
            filtered_words.appendAssumeCapacity(word);
        }
    }
}

fn rasterizeWords(words: std.ArrayList([kMaxWordLen+1]u8), rasterized_words: *std.ArrayList(u8)) !void {
    rasterized_words.clearRetainingCapacity();
    try rasterized_words.ensureTotalCapacity((kMaxWordLen+1) * words.items.len + 1);

    for (words.items) |word| {
        rasterized_words.appendSliceAssumeCapacity(word[0..word.len]);
    }
    rasterized_words.appendAssumeCapacity(0);
}

const Filter = struct {
    green_letters: [kMaxWordLen+1]u8,
    gray_letters: [30]u8,

    pub fn init() Filter {
        var filter = Filter{.green_letters = undefined, .gray_letters = undefined};
        filter.green_letters = [_]u8{0} ** filter.green_letters.len;
        filter.gray_letters = [_]u8{0} ** filter.gray_letters.len;
        return filter;
    }
};
