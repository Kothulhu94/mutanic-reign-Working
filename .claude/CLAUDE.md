## 1. CRITICAL: Godot 4.5 & GDScript 2.0 Rules
- **MUST** use static typing for all variables (`var x: float`), parameters (`func _(p: String)`), and return types (`-> void`).
- **MUST** use `class_name` to reference other scripts.
- **MUST** use modern `@onready` annotation (e.g., `@onready var node = $Node`).
- **MUST** use modern signal connection (e.g., `node.pressed.connect(my_func)`).
- **FORBIDDEN:** All Godot 3 syntax (e.g., `KinematicBody2D`, old `onready` syntax, string-based `connect()`).
- **FORBIDDEN:** Do not use `preload()` on `.gd` script files. Use `class_name` instead.
- **FORBIDDEN:** Do not use `print()` or `print_debug()` unless explicitly asked.
- **FORBIDDEN:** Do not leave `TODO` or `pass` statements. Code must be complete.

## 2. CRITICAL: Response & Workflow Protocol
**YOU MUST** follow this 3-phase process for every prompt:

1.  **Phase 1: CLARIFY & PLAN**
    - Ask **exactly three (3)** clarifying questions to remove ambiguity.
    - State a step-by-step plan based on my answers.
    - **Wait for my approval of the plan** before proceeding.

2.  **Phase 2: IMPLEMENT**
    - Implement the plan using robust, scalable, best-practice Godot architecture.
    - The solution **MUST** be production-ready and not require later refactoring.

3.  **Phase 3: DELIVER**
    - Provide the complete, verified code.
    - Briefly explain *why* the implementation follows best practices.

## 3. MCP Tool Aliases & Shortcuts
- `godot-editor`: The WebSocket-based server for editing scenes/scripts.
- `godot-runner`: The CLI-based server for running/stopping/debugging.
- `web-search`: The server for all knowledge lookups (a.k.a. "godot-docs").

- **"Godot Docs Search" Shortcut:**
  When I ask you to **"search the Godot docs"** for a topic (e.g., "signals"), you **MUST** use the `web-search` server's `full-web-search` tool and append `site:docs.godotengine.org/en/4.5/` to the query.
  - **My Prompt:** "Search the Godot docs for 'CharacterBody2D'"
  - **Your Action:** `web-search.full-web-search(query="CharacterBody2D site:docs.godotengine.org/en/4.5/")`

- **"Godot Docs Scrape" Shortcut:**
  When I ask you to **"scrape the Godot docs"** for a specific page (e.g., `class_node.html`), you **MUST** use the `web-search` server's `get-single-web-page-content` tool and prepend the base URL.
  - **My Prompt:** "Scrape the Godot docs for `classes/class_node.html`"
  - **Your Action:** `web-search.get-single-web-page-content(url="https://docs.godotengine.org/en/4.5/classes/class_node.html")`

## 4. MCP Tools Reference

### **godot-runner** (CLI-based)
- **System**: `get_godot_version`
- **Debug**: `stop_project`, `get_debug_output`
- **Project**: `launch_editor`, `run_project`, `list_projects`, `get_project_info`
- **Scene**: `create_scene`, `add_node`, `edit_node`, `remove_node`, `load_sprite`, `export_mesh_library`, `save_scene`
- **UID**: `get_uid`, `update_project_uids`

### **godot-editor** (WebSocket-based)
- **Editor**: `execute_editor_script`
- **Scene**: `create_scene`, `save_scene`, `open_scene`, `get_current_scene`, `get_project_info`, `create_resource`
- **Script**: `create_script`, `edit_script`, `get_script`, `create_script_template`
- **Node**: `create_node`, `delete_node`, `update_node_property`, `get_node_properties`, `list_nodes`

### **web-search** (Scraper-based)
- `full-web-search(query, limit)`
- `get-web-search-summaries(query, limit)`
- `get-single-web-page-content(url)`