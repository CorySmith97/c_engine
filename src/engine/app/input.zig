const MAX_KEYBOARD_KEYS = 512;

pub const KeyboardKey = enum(u32) {
    Invalid          = 0,
    Space            = 32,
    Apostrophe       = 39,
    Comma            = 44,
    Minus            = 45,
    Period           = 46,
    Slash            = 47,

    Num0             = 48,
    Num1             = 49,
    Num2             = 50,
    Num3             = 51,
    Num4             = 52,
    Num5             = 53,
    Num6             = 54,
    Num7             = 55,
    Num8             = 56,
    Num9             = 57,

    Semicolon        = 59,
    Equal            = 61,

    A                = 65,
    B                = 66,
    C                = 67,
    D                = 68,
    E                = 69,
    F                = 70,
    G                = 71,
    H                = 72,
    I                = 73,
    J                = 74,
    K                = 75,
    L                = 76,
    M                = 77,
    N                = 78,
    O                = 79,
    P                = 80,
    Q                = 81,
    R                = 82,
    S                = 83,
    T                = 84,
    U                = 85,
    V                = 86,
    W                = 87,
    X                = 88,
    Y                = 89,
    Z                = 90,

    LeftBracket      = 91,
    Backslash        = 92,
    RightBracket     = 93,
    GraveAccent      = 96,

    World1           = 161,
    World2           = 162,

    Escape           = 256,
    Enter            = 257,
    Tab              = 258,
    Backspace        = 259,
    Insert           = 260,
    Delete           = 261,
    Right            = 262,
    Left             = 263,
    Down             = 264,
    Up               = 265,
    PageUp           = 266,
    PageDown         = 267,
    Home             = 268,
    End              = 269,
    CapsLock         = 280,
    ScrollLock       = 281,
    NumLock          = 282,
    PrintScreen      = 283,
    Pause            = 284,

    F1               = 290,
    F2               = 291,
    F3               = 292,
    F4               = 293,
    F5               = 294,
    F6               = 295,
    F7               = 296,
    F8               = 297,
    F9               = 298,
    F10              = 299,
    F11              = 300,
    F12              = 301,
    F13              = 302,
    F14              = 303,
    F15              = 304,
    F16              = 305,
    F17              = 306,
    F18              = 307,
    F19              = 308,
    F20              = 309,
    F21              = 310,
    F22              = 311,
    F23              = 312,
    F24              = 313,
    F25              = 314,

    KP0              = 320,
    KP1              = 321,
    KP2              = 322,
    KP3              = 323,
    KP4              = 324,
    KP5              = 325,
    KP6              = 326,
    KP7              = 327,
    KP8              = 328,
    KP9              = 329,
    KPDecimal        = 330,
    KPDivide         = 331,
    KPMultiply       = 332,
    KPSubtract       = 333,
    KPAdd            = 334,
    KPEnter          = 335,
    KPEqual          = 336,

    LeftShift        = 340,
    LeftControl      = 341,
    LeftAlt          = 342,
    LeftSuper        = 343,
    RightShift       = 344,
    RightControl     = 345,
    RightAlt         = 346,
    RightSuper       = 347,
    Menu             = 348,
};


pub const KeyboardState = struct {
    pub var keys_pressed: [512]bool = .{false} ** 512;
    pub var keys_released: [512]bool = .{false} ** 512;
    pub var prev_keys_pressed: [512]bool = .{false} ** 512;
    pub var prev_keys_released: [512]bool = .{false} ** 512;
};

pub fn isKeyPressed(key: KeyboardKey) bool {
    var pressed = false;
    if ((key > 0) and (key < MAX_KEYBOARD_KEYS)) {
        if (!KeyboardState.prev_keys_pressed[key]
            and KeyboardState.keys_pressed[key]) {
            pressed = true;
        }
    }
    return pressed;
}

pub fn isKeyDown(key: KeyboardKey) bool {
    var pressed = false;
    if ((key > 0) and (key < MAX_KEYBOARD_KEYS)) {
        if (KeyboardState.prev_keys_pressed[key]
            and KeyboardState.keys_pressed[key]) {
            pressed = true;
        }
    }
    return pressed;
}

pub fn isKeyReleased(key: KeyboardKey) bool {
    var released = false;
    if ((key > 0) and (key < MAX_KEYBOARD_KEYS)) {
        if (!KeyboardState.prev_keys_released[key]
            and KeyboardState.keys_released[key]) {
            released = true;
        }
    }
    return released;
}

//bool IsKeyPressed(int key)
//{
//
//    bool pressed = false;
//
//    if ((key > 0) && (key < MAX_KEYBOARD_KEYS))
//    {
//        if ((CORE.Input.Keyboard.previousKeyState[key] == 0) && (CORE.Input.Keyboard.currentKeyState[key] == 1)) pressed = true;
//    }
//
//    return pressed;
//}
//
//// Check if a key has been pressed again
//bool IsKeyPressedRepeat(int key)
//{
//    bool repeat = false;
//
//    if ((key > 0) && (key < MAX_KEYBOARD_KEYS))
//    {
//        if (CORE.Input.Keyboard.keyRepeatInFrame[key] == 1) repeat = true;
//    }
//
//    return repeat;
//}
//
//// Check if a key is being pressed (key held down)
//bool IsKeyDown(int key)
//{
//    bool down = false;
//
//    if ((key > 0) && (key < MAX_KEYBOARD_KEYS))
//    {
//        if (CORE.Input.Keyboard.currentKeyState[key] == 1) down = true;
//    }
//
//    return down;
//}
//
//// Check if a key has been released once
//bool IsKeyReleased(int key)
//{
//    bool released = false;
//
//    if ((key > 0) && (key < MAX_KEYBOARD_KEYS))
//    {
//        if ((CORE.Input.Keyboard.previousKeyState[key] == 1) && (CORE.Input.Keyboard.currentKeyState[key] == 0)) released = true;
//    }
//
//    return released;
//}
//    */
