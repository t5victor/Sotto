# Sotto Design System

Sotto follows the same ownership model as shadcn/ui: component source belongs to
the application, is intentionally small, and can be changed without waiting for
an external UI framework.

## Architecture

- `SottoTheme` contains semantic colors, spacing, radii, control heights,
  typography, and motion.
- `EnvironmentValues.sottoTheme` is the single runtime injection point.
- `Components` contains domain-neutral building blocks.
- `Patterns` contains reusable Sotto-specific compositions.
- Product screens compose these pieces and avoid hard-coded brand values.

## Change the theme

Apply a theme once at the application boundary:

```swift
let theme = SottoTheme.standard.withAccent(.indigo)

SottoRootView()
    .sottoTheme(theme)
```

For deeper customization, construct `SottoTheme` or replace one of its value
groups:

```swift
var compact = SottoTheme.standard
compact.spacing = .init(xs: 3, sm: 6, md: 10, lg: 14, xl: 20, xxl: 28)
compact.radii = .init(small: 4, medium: 7, large: 10)
```

Every component consuming semantic tokens updates automatically.

Action and status colors are stored as explicit foreground/background pairs.
The automated design-system test checks every light/dark pair against WCAG AA
(at least 4.5:1) and APCA normal-text guidance (absolute Lc at least 60), so
changing a theme token cannot silently reintroduce an unreadable 13 px label.

## Add a component

1. Add the source under `Components` or `Patterns`.
2. Read values from `@Environment(\.sottoTheme)`.
3. Expose variants as small enums instead of duplicating views.
4. Preserve native SwiftUI controls for focus, keyboard, accessibility, and
   system appearance.
5. Add the new component to the appearance screen while it is being developed.

## Naming

Public components use the `Sotto` prefix to remain explicit at call sites and
avoid collisions with SwiftUI or AppKit types.
