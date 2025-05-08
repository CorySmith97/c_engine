/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-05-06
///
/// Description:
///     We use @tagName for displaying all these done.
/// ===========================================================================

pub const MainMenu = enum {
    @"New Game",
    @"Settings",
    @"Exit",
};

pub const DisplayedMenu = enum {
    none,
    main,
    pause,
    action,
    item,
    ability,
};

pub const ActionMenu = enum {
    Attack,
    Items,
    Ability,
    Wait,
};
