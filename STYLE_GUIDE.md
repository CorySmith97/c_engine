# Style Guide

Much of this is taken from Tiger beetles style guide which I think is 
an amazing starting place. However a lot has likewise been taken from 
ID software and the way that they write code. Read through the doom 
source code, and Im sure you will agree that its amazingly beautiful.

## Comments

Files should have headers providing information about the file you 
are working in. 

Format is as follows: 
```{zig}
/// ===========================================================================
///
/// Author: 
///
/// Date: 
///
/// Description:
///
/// ===========================================================================
```

Where possible leave brief comments to explain what is happening in a spot.
Comments should generally follow the following format:

```{zig}
//
// ACTUAL COMMENT CODE
/
/
```

I prefer it to be this way as it makes life so much easier. Adding a lot of space to 
the code I find makes it easier to follow the logic of the code.

Align types based off of a pattern. This makes multiline editing so much easier.
IE:

prefer:
```{zig}
const Self = @This();
field_1 : u32,
field_2 : u32,
f_3     : u32,
```


over:
```{zig}
const Self = @This();
field_1: u32,
field_2: u32,
f_3: u32,
```


## Future Tags

We all make mistakes as we are coding, and maybe you just want to get something
done for testing. PERFECT, just be sure to leave a node about it.

Tags are code comments that contain certain tags, that allow for easy codebase wide
searches to allow for better planning.

Current tags are:
```{zig}
// @todo future date

// @copypasta this code was copied from somewhere else

// @performace IE this code is likely slow and could be sped up

// @cleanup This chunk could be more concise

// @incorrect_rendering This one is temporary for explaining why rendering may be not working.

```
