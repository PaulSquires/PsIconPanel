# CIconPanel

A reusable, owner-drawn **icon strip** for FreeBASIC / Win32, built on AfxNova. Any number
of instances can coexist; each owns all of its state.

The point of this control is that **the author owns the spacing**. Every item declares its
own cell — an icon size plus the space before and after it — and the layout never adjusts,
redistributes or squeezes any of it. The one thing recomputed when the host resizes the
panel is where the whole run sits: left, centred, or right, **as one block**.

That is the difference from [CStatusBar](../CStatusBar), whose panels measure themselves
against their text and whose nominated spring panel absorbs all the slack.

- **No child controls** — the control window *is* the panel. Every item is drawn in its own
  `WM_PAINT`.
- **Static by contract**: items are built once and never inserted, deleted or moved.
- **Nothing is measured.** Cell widths are declared, so — alone in the family — the layout
  never takes a DC. The font is a paint-time input only.
- **Three item kinds**: latching `TOGGLE`, momentary `COMMAND`, and a `SEPARATOR` rule the
  control draws itself.
- **Selection is a set, not a current item.** Toggles latch independently; there is no
  `nCurSel`.
- **Built-in painter** with eight colors, or replace it wholesale with one callback.
- **Hover state** with a `WM_MOUSELEAVE` safety net; **capture-backed press/cancel** (press
  an icon, slide off, release — nothing fires).
- **On-demand tooltips** (`TTN_GETDISPINFO`), per item or via a callback.
- Flicker-free: one double buffer, one paint, per repaint.

## Files

| File | Purpose |
|---|---|
| `CIconPanel.bi` / `.inc` | The control. `CIconPanel.bi` is the documented public header. |
| `CBufferPaint.bi` / `.inc` | Flicker-free drawing helper (vendored) |
| `main.bas`, `frmMain.bi` / `.inc` | Demo / test harness (three instances, one per justification) |
| `SegoeFluentIcons.ttf` | The glyph font the demo loads privately |

Include order — no scrollbar dependency, unlike CListBox:

```freebasic
#include once "CBufferPaint.inc"
#include once "CIconPanel.inc"
```

Build:

```
fbc64.exe -i "C:\dev" main.bas
```

## Quick start

```freebasic
' Create, then position it like any window. It has no opinion about its own placement.
' Build the items once; from then on you drive them with the state setters.
dim as HWND hPanel = CIconPanel_Create( hWndParent, IDC_MYICONPANEL )

CIconPanel_SetFont( hPanel, hSegoeFluentIconsFont )    ' you keep ownership
CIconPanel_SetJustify( hPanel, IP_JUSTIFY_CENTER )
CIconPanel_SetIconSize( hPanel, 20, 20 )               ' raw pixels: you DPI-scale
CIconPanel_SetPadding( hPanel, 4, 4 )                  ' before / after each icon

dim as long idx
idx = CIconPanel_AddItem( hPanel, IP_KIND_COMMAND, wchr(&hE74E), IDM_SAVE )
CIconPanel_SetTooltipText( hPanel, idx, "Save" )

CIconPanel_AddSeparator( hPanel )

idx = CIconPanel_AddItem( hPanel, IP_KIND_TOGGLE, wchr(&hE721), IDM_FIND )
CIconPanel_SetSelected( hPanel, idx, true )            ' silent: no callback

CIconPanel_SetClickCallback( hPanel, @MyClickCallback )        ' COMMAND items
CIconPanel_SetSelChangeCallback( hPanel, @MySelChangeCallback ) ' TOGGLE items

' Size it to its content if you like, or give it the full width and let the
' justification place the run inside it.
SetWindowPos( hPanel, 0, x, y, CIconPanel_GetIdealWidth(hPanel), cy, _
              SWP_NOZORDER or SWP_SHOWWINDOW )
```

```freebasic
sub MyClickCallback( byval hCtl as HWND, byval idx as long, byval id as long )
    PostMessage( HWND_FRMMAIN, WM_COMMAND, MAKEWPARAM(id, 0), 0 )
end sub

sub MySelChangeCallback( byval hCtl as HWND, byval idx as long, byval isSelected as boolean )
    gApp.bWordWrap = isSelected
end sub
```

## The layout

```
cellWidth(i) = padBefore(i) + iconWidth(i) + padAfter(i)      TOGGLE / COMMAND
             = padBefore(i) + sepWidth     + padAfter(i)      SEPARATOR
totalW       = sum of every cellWidth                          ( = GetIdealWidth )
x0           = 0                        LEFT, or totalW >= clientW  (overflow rule)
             = (clientW - totalW) \ 2   CENTER
             = clientW - totalW         RIGHT
rc(i)        = ( x, clientTop, x + cellWidth(i), clientBottom )    full client height
rcIcon(i)    = iconW x iconH, centred in rc both ways
```

- **A resize moves `x0` and nothing else.** Relative spacing is authored and never touched.
- **On overflow the justification degrades to LEFT** and the tail clips at the right edge,
  so the leading icons stay reachable. Rects that run past the edge are computed honestly
  rather than squeezed — clipping is the paint pass's job, and the cursor can't reach past
  the edge anyway, so hit-testing stays correct for free.
- **`rc` spans the full client height**, so the hot/selected fill reads like a menu bar and
  the hit target includes the item's padding. Only `rcIcon` obeys the "centred vertically
  in the client area" rule. Want a compact pill highlight instead? Fill an inflated
  `rcIcon` from the paint callback (the demo's third panel does exactly that).
- Panel-level `SetIconSize` / `SetPadding` / `SetSeparatorWidth` take **raw pixels — you
  DPI-scale**. Only the Create-time defaults are scaled for you. Per-item overrides use
  `-1` (padding) and `0` (icon size) to mean "inherit".
- Layout is **lazy**: mutators mark it dirty and the next paint (or any rect query) runs it,
  so a burst of `AddItem` calls costs one pass. `GetIdealWidth` is valid *before* the panel
  has ever been sized — the run's width doesn't depend on the client area.

## Static by contract

Items are added once, at construction. There is no `InsertItem`, no `DeleteItem` and no
`Clear` — the API's shape enforces it rather than a comment asking nicely.

What that buys: none of the stored-index fix-up code the dynamic siblings need (three
separate sites in `CTabBar.bi` alone, and the family's most repeated bug class), because
`nLastHotIdx` and `nPressedIdx` cannot go stale. Everything a host does at runtime —
`SetSelected`, `SetEnabled`, `SetGlyph`, `SetItemForeColor` — addresses an item that is
still exactly where it was, and a callback firing mid-gesture cannot pull the pressed item
out from under the press.

Build the panel once, then drive it with the state setters. Cell widths are declared rather
than measured, so nothing moves at runtime either; only the justification moves items, and
only as one block.

## Colors and the built-in painter

`CICONPANEL_COLORS` has eight fields (`BackColor`, `ForeColor`, and Hot / Select pairs,
plus `ForeColorDisabled` and `SeparatorColor`). Defaults are tiko's dark theme. Read,
modify, write:

```freebasic
dim as CICONPANEL_COLORS clrs
CIconPanel_GetColors( hPanel, @clrs )
clrs.BackColorHot = BGR(44,49,58)
CIconPanel_SetColors( hPanel, @clrs )
```

State precedence, applied by the built-in painter and worth matching in your own:

```
disabled  >  pressed  >  hot  >  selected  >  idle
```

A disabled item is never hot or pressed (the hit-test refuses it), so the first rung is
unreachable from the others rather than merely winning over them. **Pressed reuses the
Select pair** rather than adding a ninth color: on a `COMMAND` item it is the momentary
flash that makes the icon feel like a button; on a `TOGGLE` it previews the latched look
the release is about to produce.

`CIconPanel_SetItemForeColor` overrides one item's **idle** glyph color (a red record dot,
a green run arrow). Hot, selected and disabled keep the panel's colors, so a hover always
speaks the panel's language.

Setting a `PaintItemCallback` replaces the built-in painter for **every** item, separators
included. Fill `p->rc` (not `p->rcIcon`) — `rc` is what the control background-filled.

## Callbacks

| Callback | Fires for |
|---|---|
| `PaintItemCallback` | every item, instead of the built-in painter |
| `MessageCallback` | mouse messages; return TRUE to suppress default handling |
| `TooltipCallback` | items with no tooltip text of their own |
| `ClickCallback` | a matched press+release on a `COMMAND` item |
| `SelChangeCallback` | a **user** latch/unlatch of a `TOGGLE` item |

**Programmatic setters are silent.** `CIconPanel_SetSelected` fires nothing, so a host can
call it from inside its own `SelChange` handler without recursing (Win32's
`TCM_SETCURSEL` / `TCN_SELCHANGE` precedent).

**Tooltips**: the item's own text wins; the callback is consulted only for items without
any; an item with neither shows no tip. Unlike CStatusBar/CTabBar there is no caption to
fall back on — an icon has none.

## Two traps worth knowing

**The message callback's result is IGNORED for `WM_LBUTTONUP`.** The control holds mouse
capture across a press, and the up-message is what releases it; a callback that suppressed
it would strand the capture and route every subsequent click here (the CListBox bug in
`../Learnings.md`). Suppressing `WM_LBUTTONDOWN` suppresses the press — no capture has been
taken at that point, so there is nothing to strand.

**There is deliberately no `CS_DBLCLKS` on the window class.** CStatusBar sets it; copying
that here would be a bug. With double-click messages enabled the second of two rapid clicks
arrives as `WM_LBUTTONDBLCLK` instead of `WM_LBUTTONDOWN`, so every other click on a toggle
would be swallowed — and a toolbar has no double-click semantic to gain in exchange.

## Not implemented, deliberately

- **Insert / delete / clear items.** See the static contract above.
- **Vertical orientation.** Horizontal only. A vertical sibling gets split out the day a
  second consumer needs one (the CVScrollBar / CHScrollBar precedent), not before.
- **Text labels.** Icons only; the glyph is whatever string you hand it, drawn centred in
  `rcIcon`.
- **Keyboard navigation.** The control never takes focus, so it never sees key messages.
- **Radio groups.** Toggles are independent. A host wanting mutual exclusion clears the
  siblings from inside its own `SelChange` handler — which is safe precisely because
  `SetSelected` is silent.
