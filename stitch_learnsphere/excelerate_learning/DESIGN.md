---
name: Excelerate Learning
colors:
  surface: '#f9f9ff'
  surface-dim: '#cfdaf2'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f3ff'
  surface-container: '#e7eeff'
  surface-container-high: '#dee8ff'
  surface-container-highest: '#d8e3fb'
  on-surface: '#111c2d'
  on-surface-variant: '#584237'
  inverse-surface: '#263143'
  inverse-on-surface: '#ecf1ff'
  outline: '#8c7164'
  outline-variant: '#e0c0b1'
  surface-tint: '#9d4300'
  primary: '#9d4300'
  on-primary: '#ffffff'
  primary-container: '#f97316'
  on-primary-container: '#582200'
  inverse-primary: '#ffb690'
  secondary: '#89511f'
  on-secondary: '#ffffff'
  secondary-container: '#feb379'
  on-secondary-container: '#784312'
  tertiary: '#9b451e'
  on-tertiary: '#ffffff'
  tertiary-container: '#e67e53'
  on-tertiary-container: '#5c1d00'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbca'
  primary-fixed-dim: '#ffb690'
  on-primary-fixed: '#341100'
  on-primary-fixed-variant: '#783200'
  secondary-fixed: '#ffdcc4'
  secondary-fixed-dim: '#ffb77f'
  on-secondary-fixed: '#2f1500'
  on-secondary-fixed-variant: '#6c3a08'
  tertiary-fixed: '#ffdbce'
  tertiary-fixed-dim: '#ffb598'
  on-tertiary-fixed: '#370e00'
  on-tertiary-fixed-variant: '#7c2e07'
  background: '#f9f9ff'
  on-background: '#111c2d'
  surface-variant: '#d8e3fb'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '800'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0em
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.005em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system drives a modern, high-engagement mobile Learning Management System (LMS) optimized for high retention, structured progress, and cognitive clarity. The visual language blends contemporary product minimalism with warm, energizing pedagogical accents.

- **Brand Personality**: Motivating, structured, polished, and accessible. It balances academic rigor with the approachable fluidity of consumer mobile products.
- **Target Audience**: Mobile-first learners, professional upskillers, corporate trainees, and educators navigating course pathways on iOS and Android devices.
- **Emotional Response**: Cultivates momentum, focus, accomplishment, and calm control—avoiding the visual clutter and administrative friction typical of traditional legacy LMS platforms.
- **Design Movement**: Clean Modernism with Tactile Micro-Affordances. Clean flat planes of crisp slate and pure white interact with energetic citrus accents, tactile card elevations, and rounded geometric contours.

## Colors

The palette establishes an active, high-visibility hierarchy tailored for study sessions in variable lighting conditions. 

- **Primary (`#F97316`)**: The momentum engine. Reserved for critical interactive triggers: primary task buttons, active lesson progress bars, current navigational indicators, and primary achievement cues.
- **Secondary (`#F9AF75`)**: Soft daylight tint. Deployed for low-contrast pill badges, secondary progress tracks, lesson card status tags, and soft accent containers.
- **Tertiary (`#6F2500`)**: Deep earth branding. Used for authoritative section headers, high-impact module banners, certificates, and contrast points against light orange backdrops.
- **Neutral Core**:
  - `Surface Canvas`: `#F8FAFC` (Slate-50) keeps optical fatigue low over prolonged reading sessions.
  - `Surface Card`: `#FFFFFF` pure white delivers crisp contrast against the muted canvas.
  - `Text Primary`: `#1E293B` (Slate-800) delivers WCAG AAA contrast for body and lesson content.
  - `Text Secondary`: `#64748B` (Slate-500) sets metadata, timestamps, course tags, and instructor credits.
  - `Outlines & Dividers`: `#E2E8F0` provides crisp structural delineation without visual noise.
- **Feedback & Validation**:
  - `Success`: `#10B981` (Quiz completion, passing grade, streak retention).
  - `Warning`: `#F59E0B` (Assignment deadlines within 24h, attendance alerts).
  - `Error`: `#EF4444` (Failed quiz threshold, missed submission, disconnection).

## Typography

Typography relies entirely on **Plus Jakarta Sans**, chosen for its tall x-height, clear open counters, and contemporary geometric forms that ensure high legibility on high-DPI mobile screens.

- **Hierarchy Rules**: Course titles and section headers use `headline-lg` and `headline-md` with tighter tracking (`-0.015em` to `-0.01em`) to maintain editorial punch.
- **Reading Rhythm**: Course lesson content and syllabus body copy default strictly to `body-lg` (16px base, 24px line-height) to prevent eye fatigue during lengthy text-based learning sessions.
- **Micro-labels & Meta**: `label-md` and `label-sm` are formatted with slight positive letter spacing for optimal readability when rendered in uppercase inside tags, timestamps, and difficulty indicators.

## Layout & Spacing

The spatial architecture is grounded in an 8-point layout rhythm (using 4pt half-steps for fine-grained micro-adjustments).

- **Mobile Viewport System**:
  - Screen margins: Strict `16px` (`margin`) outer edge inset for handheld one-handed ergonomics.
  - Column grid: 4-column dynamic fluid layout for mobile phones, expanding to 8 columns on foldables and tablets.
  - Gutter width: `16px` (`gutter`) between grid tiles and nested cards.
- **Rhythm Increments**:
  - `space-xs` (4px): Spacing between icon and label inside badges, indicator dots.
  - `space-sm` (8px): Spacing between input label and field, chips in horizontal scrollers, vertical stack within list rows.
  - `space-md` (16px): Standard internal card padding, gaps between form fields, stack gaps between related module items.
  - `space-lg` (24px): Separation between distinct curriculum modules, lesson sections, and CTA dock offsets.
  - `space-xl` (32px): Primary screen-level sectional dividers (e.g., separating "In Progress Courses" from "Recommended Pathways").
- **Touch Targets**: All interactive elements (tappable icons, checkboxes, navigation items) strictly preserve minimum tap dimensions of 48x48 logical pixels regardless of their internal visual boundaries.

## Elevation & Depth

Depth in this design system is physical yet subtle, pairing crisp borders with ambient, colored drop shadows to evoke natural lift and maintain structure over a light `#F8FAFC` foundation.

- **Flat Canvas (`Level 0`)**: `#F8FAFC`. Base background where all layout occurs.
- **Contained Surface (`Level 1 - Low Elevation`)**: Pure white `#FFFFFF` cards, lesson tiles, and input containers. Enforced with a structural perimeter stroke of `1px solid #E2E8F0` and subtle ambient diffusion:
  - *Shadow*: `0px 1px 3px rgba(15, 23, 42, 0.05), 0px 1px 2px rgba(15, 23, 42, 0.03)`.
- **Raised Interactive Cards (`Level 2 - Card Lift`)**: Focused course modules, expandable question drawers, and active interactive widgets:
  - *Shadow*: `0px 4px 6px -1px rgba(15, 23, 42, 0.06), 0px 2px 4px -2px rgba(15, 23, 42, 0.04)`.
- **Floating Overlays (`Level 3 - Modal & Dock`)**: Bottom action sheets, sticky "Resume Lesson" bottom docks, and navigation bars:
  - *Shadow*: `0px 10px 15px -3px rgba(15, 23, 42, 0.08), 0px 4px 6px -4px rgba(15, 23, 42, 0.03)`.
- **Primary Accent Lift**: Primary orange buttons (`#F97316`) implement an ambient tinted glow rather than a generic dark shadow:
  - *Button Glow*: `0px 4px 12px rgba(249, 115, 22, 0.28)`.

## Shapes

The design system embraces an approachable, rounded visual geometry that feels friendly and tactile without appearing toy-like.

- **Base Radius (`0.5rem` / 8px)**: Applied to micro-components such as checkbox inputs, toast notifications, progress bar runners, and small preview thumbnails.
- **Large Radius (`1rem` / 16px - `rounded-xl`)**: The default boundary for all course cards, lesson cards, modal containers, alert blocks, and bottom navigation sheets.
- **Extra Large Radius (`1.5rem` / 24px - `rounded-2xl`)**: Used for prominent featured course banners, dashboard progress overview summaries, and active video player frame enclosures.
- **Full Pill (`9999px`)**: Reserved for buttons, status badges, category filter chips, search input bars, and avatar frame outlines.

## Components

### Buttons
- **Primary CTA**: Height 52px (min 48px touch boundary), fully pill-shaped (`rounded-full`), background `#F97316`, label in white `label-lg`, with subtle ambient orange glow shadow. Pressed state: scale 0.98, background `#EA580C`.
- **Secondary / Ghost**: Height 48px, background `#F8FAFC`, border `1px solid #E2E8F0`, label in `#1E293B`.
- **Tonal Brand Button**: Background `rgba(249, 115, 22, 0.12)`, label `#6F2500` or `#EA580C` `label-lg`, zero border. Ideal for secondary actions within course contexts (e.g., "Download Syllabus").

### Cards & Lesson Items
- **Course Card**: Background `#FFFFFF`, border radius `16px`, `1px solid #E2E8F0`, padding `16px`. Top section contains visual media or topic pill; middle section holds title (`headline-sm`) and metadata row; bottom section houses the linear progress bar and resume chevron.
- **Lesson Module Accordion**: Background `#FFFFFF`, radius `12px`. Unexpanded state shows lesson index, completion icon (circle check in `#10B981` or empty lock icon in `#64748B`), title, and duration. Expanded state reveals nested micro-learning topics with vertical connector lines (`2px solid #E2E8F0`).

### Progress Indicators
- **Linear Bar**: Track height 8px, track radius `9999px`, background `#E2E8F0`. Filled track: smooth animated `#F97316` bar with rounded caps.
- **Circular Milestone Ring**: Diameter 44px, stroke 4px, background track `#E2E8F0`, fill `#F97316`. Centers a numerical percentage or tier icon in `#1E293B` `label-sm`.

### Chips & Badges
- **Status Badges**: Pill-shaped, horizontal padding 10px, vertical padding 4px.
  - Active / Enrolled: Background `#FEF3C7` (amber light) or `rgba(249, 175, 117, 0.2)`, text `#6F2500` `label-sm`.
  - Completed: Background `rgba(16, 185, 129, 0.12)`, text `#065F46` `label-sm`.
- **Filter Chips**: Height 36px, radius `9999px`. Inactive: background `#FFFFFF`, border `1px solid #E2E8F0`, text `#64748B`. Active: background `#1E293B`, text `#FFFFFF`, border-color `#1E293B`.

### Form Fields & Inputs
- **Text & Search Inputs**: Height 52px, radius `12px` (or pill for top global search), background `#FFFFFF`, border `1px solid #E2E8F0`, inner horizontal padding 16px. Placeholder text `#64748B`. Focused state: border `2px solid #F97316`, zero offset outline.

### Selection Controls
- **Radio & Checkboxes**: 22x22px outer frame, touch target 48x48px. Checkbox border radius 6px. Checked state: solid `#F97316` fill with pure white iconography. Unchecked state: `#FFFFFF` fill with `1.5px solid #CBD5E1`.

### Navigation Architecture
- **Bottom Navigation Dock**: Height 64px + safe area padding. Background `#FFFFFF` with top border `1px solid #E2E8F0`. Active tab: `#F97316` icon with 4px pill indicator beneath. Inactive tab: `#64748B` icon with label in `label-sm`.
- **Role-Based Navigation Switcher**: Header segment control with soft slate pill container `#F1F5F9`, toggling between Learner, Mentor, or Instructor dashboards with animated sliding white indicator card.