# Flappy Bird in Zig

A classic Flappy Bird clone implemented in the Zig programming language, leveraging the Raylib graphics library and the Lua scripting language.

## Overview

This project is a fun experiment and demonstration of using Zig for game development. It recreates the popular mobile game Flappy Bird, using Raylib for rendering and input handling, and integrating Lua for potentially handling game logic, configurations, or scripting aspects.

## Key Features

*   Classic Flappy Bird gameplay mechanics (tapping to flap, avoiding pipes).
*   Developed using the Zig programming language.
*   Utilizes the Raylib library for 2D graphics rendering.
*   Integrates Lua scripting capabilities (via `zlua`).
*   Configuration handled via TOML files (via `zig-toml`).

## Technologies Used

*   **Language:** Zig
*   **Graphics:** Raylib (via `raylib-zig`)
*   **Scripting:** Lua (via `zlua`)
*   **Configuration:** TOML (via `zig-toml`)

## Prerequisites

*   **Zig Compiler:** Version `0.14.0` or later (as specified in `build.zig.zon`). You can download it from the [official Zig website](https://ziglang.org/download/).
*   **Build Tools:** Standard system build tools (like GCC or Clang) required for compiling the Raylib C dependency.

## Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/0x00ASTRA/flappybird-zig.git
    cd flappybird-zig
    ```

2.  **Build the project:**
    The Zig build system will automatically fetch dependencies and compile the project.
    ```bash
    zig build
    ```

    This will create the executable in the `zig-out/bin/` directory and the required shared libraries in `zig-out/lib/`.

## Usage / Getting Started

To run the game after building:

```bash
zig build run
```

Alternatively, you can execute the compiled binary directly from the build output directory:

```bash
./zig-out/bin/FlappyBird-Zig
```

Ensure the necessary assets and potentially configuration files are in the correct location relative to the executable or run it from the project root using `zig build run`.

## Project Structure

```
flappybird-zig/
├── .gitignore          # Specifies intentionally untracked files
├── assets/             # Game assets (images, sounds, etc.)
├── build.zig           # Zig build file
├── build.zig.zon       # Zig package definition and dependency management
├── config/             # Configuration files (likely TOML)
├── scripts/            # Lua scripts
├── src/                # Source code directory
│   ├── main.zig        # Main application entry point
│   └── ...             # Other Zig source files
└── test/               # Unit tests
    └── test.zig        # Test source file
```

*   `src/`: Contains the main Zig source code for the game logic, Raylib integration, etc.
*   `assets/`: Holds graphics, sounds, and other resources used by the game.
*   `scripts/`: Likely contains Lua scripts used for game logic or events.
*   `config/`: Probably contains TOML files for game settings.
*   `build.zig`: Defines how the project is built, including fetching and linking dependencies like Raylib and Lua.
*   `build.zig.zon`: Defines the Zig package and its dependencies managed by the Zig package manager.

## Configuration

Game configuration is likely handled through files within the `config/` directory, utilizing the TOML format. Please refer to the files in the `config/` directory for specific settings and their structure.

## Contributing

Contributions are welcome! If you find a bug or have an idea for an improvement, please open an issue or submit a pull request.

## License

This project is currently unlicensed. Consider adding a license to clarify terms of use and contribution.

## Acknowledgements

*   [Raylib](https://www.raylib.com/) - A simple and easy-to-use library to enjoy videogames programming.
*   [raylib-zig](https://github.com/raysan5/raylib-zig) - Zig bindings for Raylib.
*   [Lua](https://www.lua.org/) - A powerful, efficient, lightweight, embeddable scripting language.
*   [zlua](https://github.com/sumneko/zlua) - Lua bindings for Zig.
*   [zig-toml](https://github.com/0x00ASTRA/zig-toml) - TOML parser for Zig.

---

*   *Generated README using Google Gemini*
