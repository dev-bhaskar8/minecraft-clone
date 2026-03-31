# Clawcraft

Clawcraft is a browser-based Minecraft clone built with Three.js, featuring procedural terrain generation, block placement/destruction, and first-person controls.

## Features

- **Procedural World Generation**: Generates terrain using noise functions with grass, dirt, and stone layers
- **Block Types**: 6 different block types (Grass, Dirt, Stone, Wood, Leaves, Sand)
- **Interactive Gameplay**:
  - Destroy blocks with left-click
  - Place blocks with right-click
  - Select block types with number keys (1-6) or scroll wheel
- **First-Person Controls**:
  - WASD for movement
  - Mouse for camera control
  - Space to jump
- **Environment**:
  - Procedurally generated trees
  - Animated clouds
  - Dynamic water with waves
  - Fog effects
  - Day/night sky gradient with sun
- **Physics**: Basic collision detection and gravity

## How to Play

1. Click "Start Game" to begin
2. Use the mouse to look around
3. Press **WASD** to move
4. Press **Space** to jump
5. **Left Click** to destroy blocks
6. **Right Click** to place blocks
7. Press **1-6** or scroll to select different block types

## Live Demo

Visit the live site at: [https://dev-bhaskar8.github.io/minecraft-clone/](https://dev-bhaskar8.github.io/minecraft-clone/)

## Tech Stack

- **Three.js**: 3D graphics rendering library
- **Vanilla JavaScript**: Core game logic and controls
- **HTML5/CSS3**: UI styling and layout

## Project Structure

```
clawcraft/
├── index.html    # Main game file containing all code
├── favicon.png   # Game icon
└── README.md     # Project documentation
```

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/dev-bhaskar8/minecraft-clone.git
   ```

2. Open `index.html` in your web browser

Or simply visit the GitHub Pages link to play directly in your browser!

## Controls

| Key/Mouse | Action |
|-----------|--------|
| W | Move forward |
| S | Move backward |
| A | Move left |
| D | Move right |
| Space | Jump |
| Mouse | Look around |
| Left Click | Destroy block |
| Right Click | Place block |
| 1-6 | Select block type |
| Scroll wheel | Cycle block types |
| ESC | Pause/unlock cursor |

## Block Types

| Number | Block | Color |
|--------|-------|-------|
| 1 | Grass | Green |
| 2 | Dirt | Brown |
| 3 | Stone | Gray |
| 4 | Wood | Dark brown |
| 5 | Leaves | Dark green |
| 6 | Sand | Tan |

## Development

Built as a single-file application for simplicity and ease of deployment. The entire game logic, including:

- 3D rendering with Three.js
- Procedural terrain generation
- Physics and collision detection
- UI and controls
- Textures generated programmatically

## License

This project is open source and available for educational purposes.

## Credits

Built with [Three.js](https://threejs.org/) - A powerful 3D library for the web
