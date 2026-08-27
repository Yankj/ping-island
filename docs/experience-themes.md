# Experience themes

Ping Island themes coordinate the parts of an experience that should feel like
one product—not just a color palette:

```text
IslandExperienceTheme
├── Visual       surfaces, borders, typography, icon language and window chrome
├── Interaction  allow / scoped allow / deny / neutral control appearance
├── Motion       press feedback and panel-transition timing
└── Sound
    ├── Lifecycle     processing, attention, completion, error, resource limit
    └── Auxiliary     launch, new session, approvals, reminders and usage edges
```

A CESP/OpenPeon sound pack is different: it is an optional **audio-only
override**. It never changes the selected theme's UI, icons, geometry or motion.

## Built-in experiences

Choose a theme from **Settings → Sound → Experience theme**.

| Theme | Visual language | Recommended audio |
| --- | --- | --- |
| **PingIsland native** | Ping Island's dark glass surfaces, rounded controls and existing icon treatment | The original built-in 8-bit mappings, extended to the new semantic moments |
| **macOS** | Integrated top navigation, native sidebar treatment, SF Symbols, system materials and semantic system colors | macOS system sounds |
| **Pixel** | Silkscreen type, code-rendered pixel icons, square controls and pixel grid surfaces | AgentIsland's game-style 8-bit mappings |

Pixel is one theme family with two selectable palettes:

- **Arcade Neon** — deep arcade navy with high-contrast cyan accents.
- **Game Boy Olive** — the classic four-step olive handheld palette.

Both palettes share the same components, motion and sound profile. The palette
is persisted independently, so adding a third Pixel colorway does not require a
new top-level theme or a copy of its sound mapping.

Selecting a theme applies its recommended sound source and lifecycle mapping.
Users can still customize the five lifecycle sounds afterwards, or select a
local CESP/OpenPeon pack. Changing only the Pixel palette does not reset audio.

## Semantic feedback moments

Product code emits an `AppSoundFeedbackEvent`; it never names an audio file.
The selected theme resolves that intent to either a system sound, a bundled
8-bit sound, or a compatible CESP fallback.

The original configurable moments remain:

- processing started;
- attention required;
- task completed;
- task error; and
- resource limit / compaction.

The architecture also covers launch, Island detachment, new sessions, allow,
scoped allow, deny, five-minute waiting reminders, crossing 90% usage, usage
recovery to 20% or less, and three rapid submissions within ten seconds.

Transition detection lives in `ExperienceSoundTransitions.swift`. It is theme
agnostic: it decides *what happened*, then `AppSoundFeedback` and the active
profile decide *how it sounds*. Imported CESP v1 packs do not define every new
category, so each cue documents a compatible lifecycle fallback.

## Action semantics and accessibility

Confirmation actions retain one meaning in every theme:

- Green + checkmark + label: allow this operation.
- Blue + scoped-check icon + label: allow within the current scope or session.
- Red + cross + label: deny the operation.
- Gray/neutral + hand-off icon + label: continue in the originating app.

Color is never the only indication. Controls keep labels, icons, accessibility
hints, contrast, and reduced-motion-safe press feedback in every theme.

## Source layout

```text
PingIsland/Core/
├── ExperienceThemeID.swift          persisted family and Pixel palette IDs
├── AppSoundFeedback.swift           semantic feedback entry point
└── ExperienceSoundTransitions.swift pure timing/threshold evaluators

PingIsland/UI/Themes/
├── ExperienceTheme.swift            full token and sound-profile contract
├── PingIslandExperienceTheme.swift  original product experience
├── MacOSExperienceTheme.swift       native system experience
├── PixelExperienceTheme.swift       Pixel family + both palette definitions
├── ExperienceThemeSymbols.swift     bundled font + pixel glyph renderer
└── ExperienceThemeRegistry.swift    single built-in registration point

PingIsland/UI/Components/
└── ExperienceThemeComponents.swift  semantic buttons, cards and palette picker
```

`AppLocalizedRootView` resolves the persisted family and Pixel palette, then
injects one `IslandExperienceTheme` through SwiftUI's environment. Child views
read `@Environment(\.islandExperienceTheme)` rather than reaching into settings
or defining a private palette.

The persisted PingIsland identifier remains `standard`, and PingIsland 原生 is
the default for fresh installs and invalid or missing persisted theme values.
Do not rename it: the raw value is intentionally retained to migrate existing
installations safely.

## Adding a first-party theme

Themes are compiled in; third-party UI bundles are not a runtime extension point
yet. To add a new first-party family:

1. Add a stable raw-value case to `ExperienceThemeID`. Never rename an existing
   persisted value.
2. Create `<Name>ExperienceTheme.swift` and provide every Visual, Interaction,
   Motion, lifecycle Sound and auxiliary Sound token.
3. Register one representative definition in `ExperienceThemeRegistry.all` and
   resolve variants explicitly in `theme(for:pixelPalette:)` (or a generalized
   equivalent if the new family has variants).
4. Use semantic controls and `AppSoundFeedback.play(_:)`. Do not choose action
   colors or concrete sound files in feature views.
5. If a new feedback moment is needed, add a semantic event and a pure transition
   evaluator, then supply a cue in every built-in theme.
6. Add registry, mapping, persistence and transition assertions to the Xcode
   test target, and update this user-facing table.

To add only a Pixel colorway, add a `PixelThemePaletteID` case and its palette
tokens inside `PixelExperienceTheme`; do not copy the Pixel components or sound
profile.

## Verification

The test suite verifies registration uniqueness, all three visual contracts,
Pixel palette persistence, shared Pixel audio, complete lifecycle/auxiliary cue
coverage, theme-recommended mappings and transition thresholds. Run both:

```sh
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland \
  -destination 'platform=macOS' test -only-testing:PingIslandTests
swift test --package-path Prototype
```
