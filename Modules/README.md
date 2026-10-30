# Simply Love Modules
If one wants to write code that needs to run on specific screens, Simply Love defines this notion of "modules". This is useful if one wants to incorporate third-party code into the theme without needing to edit the Simply Love files directly.

## Inner Workings
When StepMania loads, we load all the `*.lua` files in the `/Modules` directory. These modules must define and return a table where each entry in the table is a mapping from ScreenName to a single Actor/ActorFrame. These Actors will later get accumulated and added as child ActorFrames of ScreenSystemLayer. Every Actor must at least have a `ModuleCommand`. This is what gets executed whenever we load into a new screen.

When defining variables, remember to not have globals as they may pollute the global namespace.

For example, a basic module may look like the following:

```lua
local t = {}

t["ScreenSelectMusic"] = Def.ActorFrame {
    ModuleCommand=function(self)
        SCREENMAN:SystemMessage("hello from ScreenSelectMusic")
    end
}

t[Branch.GameplayScreen()] = Def.ActorFrame {
    ModuleCommand=function(self)
        SCREENMAN:SystemMessage("hello from ScreenGameplay")
    end
}

return t
```

---

## Creating Navigable Overlays with `SL.Overlay`

Modules frequently need to present interactive UI (e.g. ITL quest cards, SRPG unlocks, Archipelago notifications, or custom settings). Simply Love provides a unified overlay framework (`SL.Overlay` and `SL.OverlayManager`) to make creating navigable overlays straightforward and robust.

### Key Benefits
- **Input Exclusivity**: Opening an overlay automatically locks underlying engine input (`set_input_redirected`) for all players, preventing accidental song selections or wheel spinning.
- **Automatic Cleanup**: If a screen transition occurs or the timer expires, `SL.OverlayManager` cleans up input callbacks and resets input redirection, eliminating engine softlocks.
- **Built-in Layouts**: Includes ready-to-use `"CenteredModal"`, `"FullScreen"` (borderless full-screen prompt with dimming), and `"DualPane"` (P1/P2 side-by-side with Two-Phase Ready synchronization) archetypes.
- **Built-in Navigation**: Optional controllers (`simple_confirm`, `list`, `paged/tabs`) handle cursors, sounds, and input without boilerplate.

---

### Example 1: Centered Modal Dialog in a Module

```lua
local t = {}

local myModal = SL.Overlay.Create({
    Name = "MyModuleDialog",
    Layout = "CenteredModal",
    Width = 460,
    Height = 240,
    Title = "Archipelago Quest",
    PauseTimer = true,

    Navigation = {
        type = "simple_confirm",
        choices = { "Accept", "Later" },
        on_confirm = function(self, accepted, player)
            if accepted then
                SCREENMAN:SystemMessage("Quest Accepted!")
            end
            self:Close("confirm")
        end
    },

    Content = function(self)
        return LoadFont("Common Normal")..{
            Text = "A new song unlock location is available!\nWould you like to register this goal?",
            InitCommand = function(self)
                self:xy(0, -15):zoom(0.85):wrapwidthpixels(400)
            end
        }
    end
})

t["ScreenSelectMusic"] = Def.ActorFrame{
    myModal,
    ModuleCommand = function(self)
        -- Example: open dialog when conditions are met
        -- myModal._OverlayInstance:Open()
    end
}

return t
```

---

### Example 2: Dual-Pane Player Overlay (ITL / SRPG Style)

```lua
local resultsOverlay = SL.Overlay.Create({
    Name = "EventResultsOverlay",
    Layout = "DualPane",
    Width = 320,
    Height = 400,
    Title = function(player)
        return "Event Results - " .. ToEnumShortString(player)
    end,

    PlayerContent = function(self, player)
        local pn = ToEnumShortString(player)
        local af = Def.ActorFrame{}

        af[#af+1] = LoadFont("Common Normal")..{
            Text = "Score Synced!\n+150 Event Points",
            InitCommand = function(self) self:xy(0, -30):zoom(0.9) end
        }

        return af
    end,

    OnPlayerInput = function(self, player, event)
        if event.type == "InputEventType_FirstPress" then
            if event.GameButton == "Start" or event.GameButton == "Back" then
                -- Marks this player as ready; once both players are ready, closes automatically
                self:SetPlayerReady(player, true)
            end
        end
    end
})
```

---

### `SL.Overlay.Create` Options Reference

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Name` | `string` | `"OverlayInstance"` | Name of the root ActorFrame. |
| `Layout` | `string` | `"CenteredModal"` | `"CenteredModal"` (single box), `"FullScreen"` (borderless full-screen prompt), or `"DualPane"` (P1/P2 split). |
| `Width` | `number` | `WideScale(...)` | Frame width in pixels. |
| `Width1Player` | `number` | `WideScale(360, 420)` | Single-player pane width in `"DualPane"`. |
| `Width2Player` | `number` | `WideScale(290, 340)` | Versus 2-player pane width in `"DualPane"`. |
| `Height` | `number` | `300` | Frame height in pixels. |
| `HeaderHeight` | `number` | `36` | Height of the header bar in pixels. |
| `PaneOffset` | `number` | `(width/2) + 12` | Horizontal offset from screen center in 2-player `"DualPane"`. |
| `OffsetY` | `number` | `0` | Vertical offset from screen center in pixels. |
| `Title` | `string` or `function(player)` | `""` | Title text displayed in the header bar. |
| `TitleFont` | `string` | `"Common Bold"` | Font for the title text actor. |
| `TitleZoom` | `number` | `0.85` | Zoom scale for the title text actor. |
| `HasFooter` | `boolean` | `true` | Whether to display the default footer / ready bar in `"DualPane"`. |
| `Backdrop` | `table` or `boolean` | `true` | Fullscreen dimming quad (`{ color = color("..."), alpha = 0.85 }` or `false`). |
| `PauseTimer` | `boolean` | `false` | Whether to freeze the screen's MenuTimer while open. |
| `Content` | `function(instance)` | `nil` | Returns child actor(s) for the content slot in `"CenteredModal"`. |
| `PlayerContent` | `function(instance, player)` | `nil` | Returns child actor(s) per joined player in `"DualPane"`. |
| `FooterText` | `string` | `"&START; Dismiss"` | Custom button prompt text for the footer bar. |
| `Navigation` | `table` | `nil` | Controller config: `{ type = "simple_confirm" | "list" | "paged", ... }`. |
| `OnOpen` | `function(instance, params)` | `nil` | Hook called when the overlay opens. |
| `OnClose` | `function(instance, reason)` | `nil` | Hook called when the overlay closes. |
| `OnPaneShow` | `function(instance, player, pane, params)` | `nil` | Hook called when a pane receives a `"Show"` command (e.g. data arrival) in `"DualPane"`. |
| `OnInput` | `function(instance, event)` | `nil` | Hook for custom input handling in `"CenteredModal"`. |
| `OnPlayerInput` | `function(instance, player, event)`| `nil` | Hook for custom input handling in `"DualPane"`. |
| `OnPlayerReady` | `function(instance, player, ready)` | `nil` | Hook fired when a player's ready state changes in `"DualPane"`. |

---

### Built-in Navigation Controllers

#### `type = "simple_confirm"`
Handles Left/Right selection between confirmation choices (e.g. Yes/No), cursor bouncing, sound cues, and confirmation callbacks:
- `choices`: `table` (default: `{"Yes", "No"}`)
- `default_choice`: `number` (default: `1`)
- `on_cursor_change`: `function(instance, index)`
- `on_confirm`: `function(instance, accepted, player)`
- `on_cancel`: `function(instance, player)`

#### `type = "list"`
Handles vertical list navigation with boundary checking, wrap option, and scroll events:
- `items`: `table` of items
- `default_index`: `number` (default: `1`)
- `wrap`: `boolean` (default: `true`)
- `on_cursor_change`: `function(instance, index, item)`
- `on_select`: `function(instance, index, item, player)`
- `on_cancel`: `function(instance, player)`

#### `type = "paged"`
Handles horizontal tab/page navigation (e.g. multi-page results or evaluation breakdowns). Supports both static pages and asynchronous server-driven pages:
- `pages`: `table` of page definitions or functions (optional if setting dynamically)
- `default_page`: `number` (default: `1`)
- `wrap`: `boolean` (default: `true`)
- `on_page_change`: `function(instance, page_index, page_data, player)`
- Dynamic Page Methods:
  - `instance:SetPages([player, ] pages)`: Dynamically populates pages at runtime (supports per-player pages in `DualPane`) and immediately triggers `on_page_change` for page 1.
  - `instance:GetPages([player])`: Returns the active page table.
