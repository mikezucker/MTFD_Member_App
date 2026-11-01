# iPad layout

The existing **MTFD Member App** target supports iPhone and iPad. Select the connected iPad in Xcode's run destination; no separate app, bundle identifier, or training database is required.

## Included

- On iPadOS 18 and later, the system tab bar can expand into a sidebar. Home, Training, Policy Center, Schedule and More remain available. Sidebar shortcuts also open Dispatches, Messages, Uniforms (when permitted), Profile and Settings.
- All existing tools and role checks remain in More, including administration and tour management. Push notifications and deep links use the existing router.
- Dashboard cards use two columns when the content area is at least 940 points wide, retaining the saved order and visibility. Narrow windows and accessibility text sizes use one column. Active dispatch and call totals remain above the card grid.
- Wide dispatch details show call information, units and CAD notes beside an interactive incident map and the existing Apple Look Around street-level arrival preview. Narrow windows retain the stacked detail view and existing map fallback when Look Around is unavailable.
- Document and dispatch sheets can use a larger iPad reading area. At 900 points or wider, policy acknowledgement appears beside the PDF. Smaller windows retain the existing vertical layout.
- Shared screens have a 1200-point reading width; the login form has a 520-point reading width.

## Validation

`Tests/iPadLayout/run.sh` measures the actual production SwiftUI Layout using native hosting views. It checks containment, column gutters, row spacing with unequal-height cards, odd final rows, narrow widths and the accessibility single-column option.

Build the app with an iPad simulator destination or connected iPad. Do not pass a global `-sdk iphonesimulator` override: the scheme also builds a watchOS companion and must resolve each target's SDK independently.

## Device checks

1. Sign in and open every main tab, expand/collapse the sidebar, and open the permitted tools under More.
2. Rotate portrait/landscape and resize the app window. Check dashboard order, scrolling and larger text.
3. Open a dispatch from Home and Dispatches; check the incident address, units, CAD notes, map and street-level preview. Confirm map fallback for unavailable coverage and Done/back navigation.
4. Read a policy, open/close its PDF, and check acknowledgement placement and password contrast. Only sign a real assigned policy after reviewing it.
5. Open annual training, library, instructor session, JPR Teach/Practice/Evaluate and draft screens. Confirm existing saves and evaluation locks are unchanged.
6. Check staffing, messages, uniform order history/request form, profile and authorized admin tools.

These layout changes do not complete the separate instructional-content review or expanded instructor workflow backlog. No training content, policies, signatures, assignments, or evaluations are changed by this implementation.
