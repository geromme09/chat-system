# Flutter UI Skill (v3 — Minimal Product UI + Social UX)

Use this document as the strongest frontend implementation rule for Flutter UI work in FaceOff Social.

---

## 1. Role

Act as a senior Flutter UI/UX engineer with deep experience building modern, minimal, product-driven mobile apps and social experiences.

Prioritize:

- clarity over decoration
- fast, intuitive interactions
- strong hierarchy and spacing
- real user behavior over static mockup polish
- production-ready Flutter code

The product should feel closer to Instagram, Messenger, Notion, Linear, and Facebook-level polish than to a decorative demo app.

---

## 2. Core Rules

- One screen = one purpose.
- One primary action per screen.
- No duplicate actions or duplicate flows.
- No fake data.
- No unnecessary UI.
- No blank UI without a loading, empty, error, or active state.
- Remove anything that does not support the user’s current task.

Every UI decision must answer: “What is the user trying to do here?”

---

## 3. Visual System

Colors:

- Background: `#F7F8FB`
- Surface: `#FFFFFF`
- Primary: `#6366F1`
- Border: `#E5E7EB`
- Text primary: `#111111`
- Text secondary: `#6B7280`
- Text tertiary/helper: `#9CA3AF`

Rules:

- Keep most of the screen neutral.
- Use primary color for focus, active state, and primary actions.
- Avoid heavy cards and nested cards unless a card is truly needed.
- Avoid decorative noise, fake stats, and “future feature” UI.

---

## 4. Layout

- Prefer vertical layouts.
- Use horizontal padding `24` for auth/forms and `16–24` for social screens.
- Use generous vertical spacing: `16–24`.
- Input to input spacing: `16`.
- Section spacing: `24`.
- Avoid crowded screens.
- Keep content scannable on small iPhones.

Form screens must use:

- `SafeArea`
- `Column`
- `Expanded` content area
- fixed bottom action area

Only the content/form area should scroll. Bottom CTAs must not live inside the scrollable form.

### Spacing System (Critical)

All spacing must follow a fixed scale.

Allowed spacing values only:

- `4`
- `8`
- `12`
- `16`
- `24`
- `32`

Do not use arbitrary spacing values such as `10`, `14`, `18`, `20`, `42`, or `48` for layout gaps, padding, margins, or offsets.

Usage rules:

- Micro spacing: icon to text uses `8`.
- Tight spacing: label to input and input to helper text use `8`.
- Standard spacing: input to input uses `16`.
- Chip to chip uses `8`, or `12` only when extra touch separation is needed.
- Section to section uses `24`.
- Header to content uses `24–32`.
- Screen horizontal padding uses `24`.
- Screen vertical padding uses `16–24`.
- Bottom CTA button to footer uses `12–16`.
- Bottom CTA to safe area uses `16–24`.

Layout rules:

- Spacing must be consistent across all screens.
- Similar components must use the same spacing.
- Do not mix multiple spacing styles in one screen.
- Prefer vertical rhythm over tight grouping.
- Do not guess spacing; add a token before repeating a new spacing need.

---

## 5. Input System (Critical)

All form inputs must use the standardized `OnboardingTextField` input system unless there is a clear product reason to create a more specialized component.

Build modern, minimal, product-driven mobile inputs. Prioritize clarity, spacing, and consistency.

Core rules:

- All auth, onboarding, profile, login, registration, and future form fields must use `OnboardingTextField`.
- Inputs must be single-surface.
- No nested input containers.
- No decorated inner `TextField` boxes.
- The outer container is the input.
- Entire field must be tappable.
- Height: `56–60`.
- Border radius: `16`.
- Background: `#FFFFFF`.
- Consistent padding and spacing.
- Icon to text spacing: `12`.

Container spec:

- Horizontal padding: `16`.
- Vertical padding: about `18`, while preserving the `56–60` height.
- Default border: `#E5E7EB`, `1px`.
- Focus border: `#6366F1`, `1.5px`.
- Focus glow:

```dart
BoxShadow(
  color: Color(0xFF6366F1).withOpacity(0.12),
  blurRadius: 8,
)
```

- Animation: `AnimatedContainer`, `150ms`.
- Disabled inputs are slightly faded.

Floating label behavior is required:

- Empty state: placeholder text sits inside the input with `#9CA3AF`.
- Focused or has value: label moves above the input text.
- Floating label font size: `12`.
- Focused label color: `#6366F1`.
- Inactive floating label color: `#9CA3AF`.
- Label must not feel cramped or vertically overflow.

Icon rules:

- Left icon is required for standard fields such as email, username, password, city, and profile details.
- Right icon is optional for actions such as password visibility toggle.
- Keep icon sizing and alignment consistent across screens.

Helper text:

- Password helper text uses `12–13px`.
- Color: `#9CA3AF`.
- Placed `8px` below the input.
- Aligned with the input text column, not the icon.

Behavior:

- Smooth focus transition.
- Keyboard-safe layout.
- No overflow on small screens.
- Remove cramped labels, inconsistent padding, weak focus states, and any inner TextField container styling.

Apply to:

- Login: email or username, password.
- Registration: email, password, confirm password.
- Any future form unless explicitly exempted by product need.

Standard component:

- `OnboardingTextField`

Implementation expectation:

- Reuse the same component everywhere.
- Keep the component token-driven.
- Keep it production-ready and copy-paste safe.

---

## 6. Input Field Behavior Summary

Required input behavior:

- The outer container is the input.
- No inner decorated `TextField` box.
- Entire field is tappable.
- Height: `56–60`.
- Horizontal padding: `16`.
- Border default: `#E5E7EB`, `1px`.
- Focus border: `#6366F1`, `1.5px`.
- Focus glow: subtle primary shadow, low opacity.
- Smooth focus animation: `150ms`.
- Disabled inputs are slightly faded.
- Use floating label or clean placeholder; never cramped labels.
- Helper text uses `#9CA3AF`, `12–13px`, aligned with the text column, not the icon.

Standard component:

- `OnboardingTextField`

Use this for login, registration, onboarding, and other auth/profile form inputs.

---

## 7. CTA Rules

Primary CTAs on forms must be bottom anchored.

Requirements:

- One primary CTA per screen.
- Full-width button.
- Height: `56–58`.
- Radius: `14–16`.
- Primary color: `#6366F1`.
- Always thumb-reachable.
- Keyboard-safe.
- Button to footer spacing: `12–16`.
- Footer to bottom safe area: `12–20`.
- No floating middle buttons.
- No large dead space between button and footer.

Standard components:

- `PrimaryButton`
- `BottomActionArea`

`BottomActionArea` must use `AnimatedPadding` with `MediaQuery.viewInsets.bottom` so the CTA moves smoothly above the keyboard.

---

## 8. Typography

- Title: bold and clearly dominant.
- Subtitle: muted, `#6B7280`.
- Helper text: `#9CA3AF`, small.
- Use 2–3 font weights only.
- Avoid decorative typography.
- Text must not overflow inside buttons, inputs, cards, or list rows.

---

## 9. Interaction

- Tap feedback should feel immediate.
- Smooth animations: `150ms` by default.
- Dismiss keyboard on tap outside.
- Use `resizeToAvoidBottomInset: true`.
- Avoid overflow on small screens.
- Forms must remain usable while the keyboard is open.
- Like and other social reactions must feel instant.

---

## 10. Auth Screen Standards

Login screen:

- Title: “Welcome back”
- Subtitle below title.
- Email or username input.
- Password input with show/hide toggle.
- “Forgot password?” under password, right-aligned.
- Bottom CTA: “Sign in”.
- Footer: “Create account” or “Don’t have an account? Create account”.
- No outer card container around inputs.

Registration screen:

- Title: “Create your account”
- Subtitle below title.
- Email input.
- Password input.
- Confirm password input.
- Password helper text under password.
- Agreement checkbox.
- Bottom CTA: “Continue”.
- Footer: “Already have an account? Sign in”.
- No outer card container around inputs.

Both screens:

- Reuse `OnboardingTextField`.
- Reuse `PrimaryButton`.
- Reuse `BottomActionArea`.
- Use `TextEditingController`.
- Add basic validation.
- Keep CTA bottom anchored.
- Keep layout keyboard-safe.

---

## 11. Social Product Rules

Every social screen must handle:

- Loading
- Empty
- Error
- Active

Never leave blank UI without explanation.

Feed:

- Content-first design; posts matter more than chrome.
- Avoid heavy cards.
- Each post must be quick to scan.
- Like/comment actions must be immediately visible.
- Empty state: clear message and one useful action.

Post interactions:

- Like must feel instant.
- Comment should open smoothly.
- Avoid multi-step interactions.

Comments:

- Simple, fast input at the bottom.
- Show relevant comments first.
- Keep threading flat or one-level initially.

Messaging:

- Messages grouped by sender.
- Do not repeat avatar on every message in a group.
- Input always visible at bottom.
- Keyboard must not break layout.
- Messages should feel real-time.

Friends:

- Add friend has one clear entry point.
- Friend requests must be obvious with accept/decline.
- No duplicate friend flows across screens.

---

## 12. Component Standardization

Create and reuse shared components where they match the product surface:

- `OnboardingTextField`
- `PrimaryButton`
- `BottomActionArea`
- `PostCard`
- `CommentInputBar`
- `LikeButton`
- `MessageBubble`
- `ChatInputBar`

Rules:

- Do not create one-off component clones.
- Keep shared components token-driven.
- Keep components small and composable.
- Prefer `StatelessWidget` where possible.

---

## 13. Code Standards

- Use Flutter/Dart only for mobile UI.
- Organize by feature.
- Keep shared UI in `core` or a clearly shared presentation module.
- Use reusable widgets.
- Avoid large build methods.
- Separate UI, state, and data access.
- Do not hardcode design values when a token exists.
- Add tokens before repeating magic numbers.
- Use `ListView.builder` for feeds, comments, friends, and chats.
- Use safe keyboard handling with `MediaQuery.viewInsets`.
- Use `AnimatedContainer` or equivalent for focus/interaction transitions.
- Produce production-ready code only.

---

## 14. Do Not

- Do not use double-container inputs.
- Do not implement form inputs without `OnboardingTextField`.
- Do not put form CTAs in the middle of the screen.
- Do not add heavy outer cards around simple auth forms.
- Do not duplicate primary actions.
- Do not show fake content as real content.
- Do not mix screen purposes.
- Do not sacrifice usability for aesthetics.
- Do not leave loading, empty, or error states undesigned.

---

## 15. Output Rule

When asked to implement UI:

- Make the code changes directly.
- Keep scope tight.
- Reuse existing tokens and components.
- Add missing shared components only when they improve consistency.
- Run formatter and analyzer when possible.
- Report what changed and what was verified.
