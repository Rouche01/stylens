# Closet item view

Locked product decisions for tap-through from the closet grid. HTML mock: [`closet-item-preview.html`](./closet-item-preview.html).

Backend identity and try-on rules stay in [stylens-lite-api `plan_closet_shoppable.md`](../../stylens-lite-api/docs/plan_closet_shoppable.md). This note is the client UX we agreed.

---

## What we are building

Tap a closet tile → item screen.

1. **Hero** is the full outfit photo, not a zoomed crop.
2. **This piece** is marked with its percent bounding box. Everything outside the box is dimmed (keep the rest of the outfit readable).
3. **Product shots** underneath are optional matches for try-on and a cleaner presentation. They are not “this is your jacket.”
4. **Edit** sits on the right of the header row (back · title · edit).

The boxed worn photo is closet identity. A catalog JPEG is a stand-in, never the source of truth.

---

## Item screen

**Header (same row)**

- Back (left)
- Item display name immediately after back (left-aligned, not centered)
- Edit (right)

**Hero**

- Full original outfit (`original_image_url` + `bounding_box`).
- One box for the selected item. Client overlay from percent `x, y, width, height` (0–100).
- Light dim outside the box. Do not replace this view with an isolate cutout or a tight crop.
- Caption under the photo in the same flush card: name + “Worn in this outfit” (wear count can come later). Not overlaid on the box.

If the box is missing, show the photo without a fake box.

**Product row**

Locked copy:

> **Looks like yours?**
>
> Tap a photo if it’s this jacket. We’ll use it for a cleaner presentation, or to try it on your twin.

(Swap “jacket” for the item’s display name.)

- Three (or so) catalog / shoppable stills.
- Tap to select. Outline the chosen one.
- **None of these** clears the selection.
- Do not auto-select the first result.
- Skip / empty recs is fine; the screen still works as boxed detail.

**Not in v1 of this screen**

- Wear history strip (plan later; each wear keeps its own photo + box).
- Putting product photos on the All / Categories control.

---

## Closet tile photo preference

The grid already picks a URL per tile. Persist which source to show.

**Default:** outfit isolate / padded crop (`isolated_image_url`, fallback padded crop). Product-as-tile is opt-in so a bad catalog match cannot quietly replace what they own.

**Two layers**

1. **Per item (primary).** When they pick a product on this screen, or later under Edit: **Show this in my closet** vs **Keep the outfit photo**. This is the moment both images are in front of them.
2. **Whole closet (secondary).** Profile / Settings: **Closet tiles: outfit photos / product photos when matched.** Unmatched items always stay on the outfit crop.

**Do not** put this on All vs Categories. That control is layout, not image source.

**Detail hero always uses the worn outfit + box**, even when the grid tile uses the product shot.

---

## Copy and chrome we already locked (related)

Empty closet: [`closet-empty-preview.html`](./closet-empty-preview.html)

- Title: **Nothing hanging yet**
- Capture CTA, not a fake dashed grid

Pending identity asks: [`closet-review-preview.html`](./closet-review-preview.html)

- Same compact banner in All and Categories (under the toolbar, not a “Pending” category).
- One match at a time. After resolve, settle copy, then the next pair.
- Ask banner: **Same white tee?** / **Looks like one already in your closet** (no 1 of 3).
- Remaining count only after a decision: **2 left to confirm** / **1 left to confirm**.
- Same / New live on the sheet, not the banner.

---

## Implementation notes (when we build)

- Overlay the box on the client. No server-composited annotated JPEG for v1.
- Fresh signed `original_image_url` + `image_key` + `bounding_box` on `GET /closet/items/:id` (already called out in the API shoppable plan).
- Selected product is a **link** (image URL, title, source) for try-on / optional tile, not a write over closet identity fields.
- Twin try-on still uses the product photo, not a SAM cutout of the selfie.

---

## Explicitly not this

Replacing the boxed hero with a catalog image. Auto-picking a product. Swipe-dismiss pending asks as “same.”
