# Platform

A minimal Common Lisp platformer scaffold built with [cl-sdl2](https://github.com/lispgames/cl-sdl2). It opens a 1024x768 window, draws a player rectangle and ground, runs a fixed-step update loop, and handles basic movement, jumping, gravity, and collision. The player resets if they fall off-screen, ESC quits, and the HUD displays a placeholder score using SDL2-ttf. Codex worked through the environment quirks in this repo so you can clone and get moving quickly.

## Prerequisites

- SBCL (tested with recent releases)
- Quicklisp with `(ql:quickload '(:sdl2 :sdl2-image :sdl2-ttf))` working
- SDL2, SDL2_image, SDL2_ttf libraries installed on your system
- A TrueType font file. By default the game looks for `resources/DejaVuSans.ttf`, common Arial locations, or the path specified in the `PLATFORM_FONT_PATH` environment variable.

## Quick start

1. **Install SDL2 + SBCL**

   - macOS: `brew install sbcl sdl2 sdl2_ttf`
   - Debian/Ubuntu: `sudo apt install sbcl libsdl2-dev libsdl2-ttf-dev`
   - Windows: install SBCL from [sbcl.org](https://www.sbcl.org/) and the SDL2/SDL2_ttf runtime DLLs.

2. **Run the helper script**

   ```bash
   ./scripts/run.sh
   ```

   The script will:

   - fetch a local copy of Quicklisp (kept inside `.quicklisp/`)
   - download a DejaVuSans font into `resources/`
   - load the `:platform` system and launch the game

   The window opens at 1024×768. Move with ←/→, jump with space, reset with `R`, and exit with `ESC` or by closing the window. If you need to point at a different font, set `PLATFORM_FONT_PATH` before running the script. For automated/headless runs you can call `(platform:main :auto-quit-seconds 5)` from a REPL to self-terminate after a delay.

## Project layout

```
platform.asd        ; ASDF system definition
src/main.lisp       ; Game entry point and logic
resources/          ; Place fonts or other assets here
scripts/run.sh      ; One-shot launcher (bootstraps Quicklisp + fonts)
```

Feel free to extend the scaffold: add sprites, more platforms, enemies, or a scoring system. The code is intentionally small and commented so it can grow with your project.
