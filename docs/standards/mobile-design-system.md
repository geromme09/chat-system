# Mobile Design System

This document defines the visual direction for the Flutter app so new pages stay consistent while the product grows.

This design system should be used together with [flutter-ui-skill.md](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/docs/standards/flutter-ui-skill.md). If the two ever conflict, the Flutter UI skill should be treated as the stronger frontend implementation rule.

## Design direction
The product should feel:
- mobile-first
- clean and minimal
- youthful without looking loud
- social and confident, not romantic or overly corporate
- confident, simple, and easy to scan

Reference tone:
- Gen Z minimal
- editorial spacing
- bold but restrained typography
- soft neutral backgrounds
- subtle playful accents
- low clutter

## Core principles
- Keep the layout airy. Let whitespace do the work.
- Use bold headlines and restrained supporting text.
- Avoid crowded dashboards and too many cards on screen at once.
- Prefer one strong CTA per section.
- Make the product feel real-world and social, not fantasy-gamified.
- Avoid default startup-app gradients everywhere. Use accents sparingly.

## Color system
Primary colors:
- `ink`: `#1A1A1A`
- `paper`: `#FAFAFA`
- `card`: `#FFFFFF`
- `line`: `#ECECEC`
- `slate`: `#6B7280`

Accent colors:
- `coral`: `#F59E8B`
- `softBlue`: `#AFCBFF`

Usage rules:
- `ink` is the main anchor color for text and primary actions.
- `paper` is the default page background.
- `card` is the default surface for cards and input containers.
- `line` is the default stroke/border color.
- `slate` is for supporting body text only.
- `coral` is the default primary accent for warmth and personality.
- `softBlue` is the secondary accent when a second accent is needed.
- Never use more than 2 accents in one screen.

Do not:
- add random new accent colors per page
- use purple-heavy gradients
- use dark mode as the default visual identity

## Typography
Tone:
- headlines should feel sharp, tight, and assertive
- body text should stay neutral and readable

Rules:
- headline text should use bold weight and slightly tighter letter spacing
- body text should use normal spacing and generous line height
- avoid decorative fonts unless the full app direction changes intentionally
- keep text blocks short and scannable
- use at most 2 to 3 font weights across a screen

Preferred hierarchy:
- display headlines for onboarding hero copy
- headline for page titles
- title for section headings
- body for supporting copy

## Surfaces and shapes
- Use rounded rectangles with medium radius, not extreme bubble styling
- Default card radius: `16` to `20`
- Default input/button radius: `12` to `16`
- Prefer bordered flat cards with very light shadow only
- Avoid deep shadows
- Keep shadows subtle enough that the UI still feels calm

## Spacing
Default rhythm:
- page side padding: `24`
- section gap: `18` to `28`
- item gap inside a card: `8` to `16`

Spacing scale:
- `4, 8, 12, 16, 24, 32`

Rules:
- do not stack too many competing sections without whitespace
- prefer vertical rhythm over dense grid layouts in the early app

## Buttons
Primary button:
- filled with `ink`
- white text
- used for the main action only

Secondary button:
- outlined with `line`
- `ink` text
- used for lower-priority actions

Rules:
- avoid placing many equal-weight CTAs next to each other
- keep button labels short and direct
- keep screens to 1 or 2 main actions when possible

## Inputs and forms
- inputs should feel soft, clear, and calm
- use filled surfaces with subtle borders
- labels should be straightforward
- validation messages should stay short and useful

Rules:
- keep forms vertically stacked
- avoid multi-column form layouts on mobile
- if a form is long, group it into 2 or more visual sections

## Iconography and illustrations
- prefer simple rounded Material icons
- icons should support the layout, not dominate it
- use small decorative shapes instead of full illustrations when possible

## Motion
- keep motion subtle
- use route transitions and small reveal motions only where needed
- avoid playful bounce everywhere

## Screen patterns
### Welcome and onboarding
- one clear headline
- one short supporting paragraph
- a lightweight preview of the product values
- primary CTA followed by one secondary CTA

### Auth screens
- clear title
- minimal explanation
- photo/profile trust cues
- one main form card

### Chat screens
- calmer, utility-first layout
- focus on readability and message access
- accents should be lighter than onboarding

### Future discovery and challenge screens
- keep the same base palette
- use `coral` or `softBlue` for active status or selected states
- do not overload the UI with neon game or combat styling

## Product-specific tone
This app is about:
- meeting real people
- chatting
- building friendships
- sharing identity
- staying connected before and after gameplay exists

The UI should communicate:
- trust
- movement
- local connection
- social confidence

The UI should avoid communicating:
- pure dating app energy
- casino or gaming UI energy
- generic enterprise dashboard energy

## Consistency checklist
Before shipping a new screen, check:
- does it use the shared color system?
- does it keep the spacing rhythm?
- is there one clear primary action?
- does the page feel calm and confident instead of crowded?
- does it match the FaceOff Social tone of the product?
