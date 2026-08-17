# Sotto Design System

Sotto keeps its component source in the application. The components are small,
native SwiftUI views that can change with the product without pulling in a
separate UI framework or web implementation. The default visual direction comes
from the current Sotto v1 reference and is implemented in SwiftUI.

## Architecture

- `SottoTheme` contains colors, spacing, radii, control heights, typography and
  motion using semantic names.
- `EnvironmentValues.sottoTheme` is the runtime injection point.
- `Components` contains reusable building blocks such as buttons, cards, badges,
  fields, switches, icons and dividers.
- `Patterns` contains Sotto-specific compositions such as the recording pill,
  permission row and pixel activity indicator.
- Product screens compose these sources instead of defining brand constants.

## Reference tokens

The neutral scale is explicit, so the app does not depend on AppKit system
colors:

| Role | Light | Dark |
| --- | --- | --- |
| Page | `#FAFAFB` | `#17181A` |
| Canvas | `#F1F2F3` | `#1C1D1F` |
| Surface | `#FFFFFF` | `#232427` |
| Inset | `#F7F8F9` | `#1F2022` |
| Field | `#F2F2F3` | `#2B2C2F` |
| Hover | `#F4F5F6` | `#2A2B2E` |
| Strong hover | `#E7E9EB` | `#313236` |
| Hairline | `#ECEDEF` | `#2E3033` |
| Strong hairline | `#E0E2E5` | `#3A3C40` |
| Ink | `#1F2124` | `#F2F3F4` |
| Secondary ink | `#62656B` | `#A5A8AD` |
| Tertiary ink | `#9A9DA3` | `#6C6F75` |
| Accent | `#0285FF` | `#3D9AFF` |

The accent is fixed. Primary action labels use `accentInk`, and the destructive
action uses a darker red derivative so 12.5 px labels meet WCAG AA and APCA
normal-text contrast. Status backgrounds keep their reference tints, with
foreground colors chosen as accessible pairs.

Cards use a 10 px radius; fields and selectors use 8 px. Status badges and
actions use capsules, and compact controls range from 28 to 38 px. Borders are
one-pixel hairlines.

The main window uses one continuous surface. Standard cards are transparent
layout wrappers, raised cards use the canvas tone once, and muted cards are
reserved for secondary context. Controls use flat fills and capsules instead
of shadows. Navigation uses text-first rows, with icons where they clarify state
or action.

## Typography and icons

Inter Variable is the interface font. JetBrains Mono Variable is used for
keyboard shortcuts and compact machine-readable values. Both fonts and their
SIL Open Font License 1.1 files are bundled in the SwiftPM application resource
bundle and registered before the first view is created.

`SottoIcon` centralizes a 24-point monochrome outline language at 11–17 px
rendering sizes. Individual screens choose semantic symbols, but no longer
choose arbitrary weights, colors or frames.

## Motion

Motion is limited to places where it explains state or confirms input:

- buttons scale to 0.97 for 100 ms on press;
- hover and selected surfaces transition in 100–150 ms;
- the first appearance of each destination uses an 8 px, 350 ms ease-out reveal
  with a short stagger;
- local model work uses a 3×3 pixel loader and a restrained text shimmer;
- listening uses the real microphone level rather than decorative looping
  motion.

The hotkey-triggered overlay appears immediately because it is a frequent
keyboard action. Decorative movement follows macOS Reduce Motion; meaningful
color and opacity feedback remains available.

## Change the theme

Apply a theme once at the application boundary:

```swift
SottoRootView(model: model)
    .sottoTheme(.standard)
```

For deeper customization, construct `SottoTheme` or replace one of its value
groups:

```swift
var compact = SottoTheme.standard
compact.spacing = .init(xs: 3, sm: 6, md: 10, lg: 14, xl: 20, xxl: 28)
compact.radii = .init(small: 5, medium: 7, large: 9)
compact = compact.withAccent(.indigo, foreground: .white)
```

Every component that reads these tokens updates automatically. Older accent
values still decode from preferences. The shipped v1 baseline uses the fixed
blue accent.

## Validation

Action and status colors are stored as foreground/background pairs. The design
system tests pin the reference tokens and check every text-bearing pair against
WCAG AA (at least 4.5:1) and APCA normal-text guidance (absolute Lc at least
60).

When adding a component:

1. Add its source under `Components` or `Patterns`.
2. Read values from `@Environment(\.sottoTheme)`.
3. Expose a small finite variant enum instead of duplicating views.
4. Preserve native focus, keyboard and accessibility behavior.
5. Add the component to the appearance gallery while developing it.

Public components use the `Sotto` prefix to avoid collisions with SwiftUI and
AppKit types.
