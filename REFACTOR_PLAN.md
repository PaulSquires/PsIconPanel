# CIconPanel — design notes

Why this control is shaped the way it is. `README.md` covers usage; this file covers the
decisions, so they don't get re-litigated later.

## Where it came from

`C:\dev` carries a family of reusable owner-drawn controls (`CListBox`, `CVScrollBar`,
`CHScrollBar`, `CStatusBar`, `CTabBar`, `CTextBox`, `CMenuBar`/`CPopupMenu`,
`CColumnHeader`, `CSplitter`), all built to one template and all folded into tiko. Missing
from the set was a **toolbar-shaped icon strip** where the author, not a layout algorithm,
decides the spacing.

CStatusBar was the near-miss and the seed: fully owner-drawn, one WndProc, no child to
subclass, hover tracking and on-demand tooltips already in the right shape. It was copied
and adapted. Per CLAUDE.md, every inherited comment was audited — see *Inherited claims
that did not survive* below, because two of them were actively wrong here.

## Decisions

**Author-controlled flow, block-justified.** Each item declares `padBefore + icon +
padAfter`. The layout lays cells out in the supplied order and never adjusts them. The only
thing a resize recomputes is `x0`, the offset of the whole run. This is the entire reason
the control exists; anything that redistributes space (a spring panel, shrink-to-fit,
padding compression) is out of scope by definition, not by omission.

Considered and rejected: **per-item absolute X positions**. It sounds like more control but
buys less — the author already controls every gap, and absolute positions would need their
own rules for overlap, ordering and what justification even means. The flow expresses the
same intent with one coordinate system instead of two.

**Nothing is measured.** Cell widths are declared, so `LayoutItems` never takes a DC and
never calls `GetTextExtentPoint32W`. Alone in the family, this control's font is a
paint-time input: `SetFont` repaints but does not re-lay-out, and `SetGlyph` invalidates
one item rather than dirtying the layout. The cost is that an oversized font clips instead
of growing its cell — correct here, since a fixed grid is the whole point.

**Static item set** (adopted 2026-07-21, after CSelectBar — see *The static refactor* below).
Items are added once and never inserted, deleted or moved.

**Multi-select toggles, not a current item.** `CTabBar` owns one `nCurSel`; this control
owns a set of independent switches, so `isSelected` lives on the item. Contrast `isHot`,
which stays single-valued on the control (`nLastHotIdx`) exactly as everywhere else in the
family — hover is transient and single-valued, so a per-item copy would be a second source
of truth to keep in sync.

Radio behaviour is a host concern: clear the siblings from inside the `SelChange` handler.
That is safe precisely because programmatic `SetSelected` is silent, so it cannot recurse.

**Three item kinds.** Multi-select toggling alone would strand momentary buttons ("Run"
must not stay lit), so `IP_KIND_COMMAND` latches nothing and reports through a separate
`ClickCallback`. `IP_KIND_SEPARATOR` is a control-drawn rule that is deliberately **not
hit-testable** — it never goes hot, never presses, and `HitTest` returns -1 for it.
Separator visuals could have been left to padding alone, but a rule is what actually reads
as a group boundary, and giving it a kind keeps it out of `FindItemByID`'s results.

**Capture: yes.** The family's stated test is "does something consume the guaranteed
`WM_LBUTTONDOWN` → `WM_LBUTTONUP` pairing?" Here something does: the press/cancel gesture.
Press an icon, slide off, release — nothing fires. Knowing the press is still live while
the cursor is elsewhere is exactly what capture buys. The full price is paid: snapshot the
pressed index before releasing, release on the up-message before any callback runs, callback
result ignored for the up-message, `WM_CAPTURECHANGED` cancels, `WM_DESTROY` releases.

**No `bPressedInside` flag.** "The cursor is still on the pressed item" is exactly
`nLastHotIdx = nPressedIdx`, and hover tracking already maintains that through the capture
(moves outside the client report -1). One fact, one place.

**Built-in painter, overridable.** Colors with defaults, settable by the host, was a stated
requirement — which points at CMenuBar's shape (a built-in painter plus an optional
callback that replaces it wholesale) rather than CStatusBar's (a paint callback is
mandatory or nothing is drawn). Pressed reuses the Select color pair instead of adding a
ninth color.

**`rc` spans the full client height; only `rcIcon` is vertically centred.** The cell is the
fill and hit target, so the highlight reads like a menu bar and the target is
Fitts-friendly. A host wanting a compact pill fills an inflated `rcIcon` from the paint
callback — the demo's third panel does, which is also what proves the override path works.

## Inherited claims that did not survive the copy

Copying the nearest sibling means auditing every comment for claims that no longer hold.
Two mattered:

1. **"The control takes NO mouse capture."** True of CStatusBar, false here. The WndProc
   header now states the opposite and lists the four obligations that come with it.
2. **`CS_DBLCLKS` on the window class.** CStatusBar enables it. Copying that would have
   been a live bug: with double-click messages enabled the second of two rapid clicks
   arrives as `WM_LBUTTONDBLCLK` rather than `WM_LBUTTONDOWN`, so every other click on a
   toggle would be swallowed — and a toolbar has no double-click semantic to gain in
   exchange. It is deliberately absent, and the code says so.

## The static refactor (2026-07-21)

Building **CSelectBar** a day later made the point retroactively: that control was static
from the start, and the absence of insert/delete turned out to remove not just two entry
points but a whole category of code. CIconPanel had the same real usage — a toolbar's
buttons are decided at construction and then merely toggled, enabled and recoloured — while
still carrying the dynamic machinery. So it was brought into line.

Removed: `CIconPanel_InsertItem`, `CIconPanel_DeleteItem`, `CIconPanel_Clear`, and the type's
`InsertItemAt` / `DeleteItemAt` / `Clear`. `AddItem` became a plain append instead of
`InsertItemAt(itemCount)`.

What went with them, and is the actual point of the change:

- **The stored-index fix-up code.** Insert shifted `nLastHotIdx` up; delete shifted it down,
  or cleared it when the hot item was the one deleted, then re-clamped it against the new
  count. That pattern is the family's most repeated bug class (three separate sites in
  `CTabBar.bi`), and it is now absent rather than merely correct.
- **"Any item mutation cancels a live press."** Both mutators called `CancelPress` because a
  shifted or vanished item made the pressed index meaningless mid-gesture. With a static
  set the pressed index cannot go stale, so `CancelPress` survives only where it is
  genuinely needed: capture loss, and `SetEnabled` disabling the pressed item.
- **A dangling-pointer hazard in `WM_LBUTTONUP`.** The re-check there was guarding against a
  callback deleting items mid-gesture. It now guards only against a callback *disabling* the
  item, which is the one thing still possible — and the comment says so, rather than
  implying a risk that no longer exists.

Nothing in the demo harness used the removed functions, so the change is API-narrowing only.
The panel's behaviour is unchanged; this is a subtraction, not a redesign.

**One deliberate asymmetry with CSelectBar: it keeps `Clear`, this control does not.** Not
an oversight and not worth harmonising. A select bar's labels are the sort of thing a host
re-localises or rebuilds wholesale, so it keeps one escape hatch for exactly that; an icon
panel's glyphs are fixed at construction and a host that wants a different set wants a
different panel. Both remain static in the sense that matters — no insert, no delete, no
index fix-up code — which is the property the contract is actually about.

## Bugs found during the build

**`ReleaseCapture()` fires `WM_CAPTURECHANGED` synchronously.** The first draft of
`WM_LBUTTONUP` released capture and *then* read `nPressedIdx` — but the capture-changed
handler cancels the press, so the read always found -1 and no click would ever have fired.
The pressed index is now snapshotted before the release. The release still happens before
any callback runs.

**`GetIdealWidth` returned 0 until the panel had been sized.** `LayoutItems` bailed out on
a zero-size client before computing `nTotalWidth`, which is a chicken-and-egg trap for the
one caller that matters: a host asking how wide to make the panel. The run's width doesn't
depend on the client area at all — only `x0` does — so the width pass now runs first and
the bail-out sits between it and the placement pass.

## Verification

- Builds clean, zero warnings: `fbc64.exe -i "C:\dev" main.bas`.
- **Geometry was asserted, not eyeballed** (CLAUDE.md). A temporary trace sized each of the
  three panels to a width that fits (900) and one that overflows (200), dumped `clientW`,
  `totalW`, `x0` and every `rc`/`rcIcon`, and checked five invariants per item against the
  formula recomputed independently: block offset, cell contiguity, full-height cells,
  vertical centring of `rcIcon`, and `rcIcon` inside its own cell — plus the run's total
  width. 6/6 configurations PASS. The trace was removed afterwards; there is no shipped
  `CICONPANEL_SELFTEST` env gate (declined during design in favour of the throwaway trace).
- Traced strings were built as `dim as string` first — `print` on a `DWSTRING`, or on a
  `string & wstring` concat, interleaves nulls (`../Learnings.md`).

**Interactive pass: PASSED** (author, 2026-07-21) — pixel appearance, hover, the
press/cancel gesture, capture behaviour, tooltip timing, and rapid clicking of a toggle
(the `CS_DBLCLKS` decision above). Synthetic input was deliberately not used to stand in
for it: `SendMessage`-simulated clicks cannot reproduce capture, which is precisely the
path most worth testing (`../Learnings.md`, *Verifying GUI work without a debugger*).

## Possible future work

- **tiko fold-in.** The obvious consumers are the Explorer/Output panel header strips and
  any place tiko currently hand-draws a row of Fluent glyphs.
- **A vertical sibling** (`CVIconPanel`), the day a second consumer needs one — split out
  rather than folded in, following CVScrollBar → CHScrollBar.
- **Overflow chevron.** Today the tail simply clips. A "»" affordance that opens the
  remaining items in a `CPopupMenu` would be the natural escape valve, and the popup
  control already exists.
