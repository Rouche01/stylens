# Closet review asks

Locked product + Flutter plan for pending identity matches. HTML mock: [`closet-review-preview.html`](./closet-review-preview.html). Related copy already in [`plan_closet_item_view.md`](./plan_closet_item_view.md).

Backend already ships this in stylens-lite-api. This note is the client UX. Do not invent a second API.

- `GET /closet/matches/pending` → `{ matches: ClosetPendingMatch[] }` newest first
- `POST /closet/matches/:id/resolve` `{ decision: "same" | "new" }`

`processing` wait chrome stays in its own slot (dock chip / empty hang). Asks stay **under the toolbar**. Both can show at once.

---

## What we are building

Identity can leave a queue of “is this the same piece?” pairs. The closet shows **one compact banner**, then a sheet to decide Same / New. Confirmed pieces stay in the masonry. Pending crops are not closet tiles until **new**.

Push (`type=closet_matches`) is how they come back. The closet screen is how they resolve. Do not use a Pending category.

---

## API contract (do not invent a second one)

No match-specific realtime event. Catch-up `GET /closet/matches/pending` (no cache) on bind, resume, closet tab, identity `settled`, `closet_catalog_updated`, and after a successful resolve. Do not poll.

**List**

```json
{
  "matches": [
    {
      "id": "…",
      "outfit_id": "…",
      "created_at": 0,
      "probe": {
        "label": "white tee",
        "category": "top",
        "isolated_image_url": "…",
        "original_image_url": "…"
      },
      "candidate": {
        "closet_item_id": "…",
        "label": "white tee",
        "isolated_image_url": "…",
        "original_image_url": "…"
      }
    }
  ]
}
```

Keep `score` / `cosine` / `color_distance` / boxes on the model. **Do not render scores.** Thumbs: isolate URL with `cutout=0` (photo crop of the boxed item), then `original_image_url`. Do not use the SAM silhouette.

API order is `created_at DESC` (newest first). The banner is `matches.first`.

**Resolve** `{ decision: "same" | "new" }`

| Decision | App does |
| --- | --- |
| `same` | No extra tile. Settle **Saved as the same piece**. |
| `new` | `fetchItems(forceRefresh: true)` (catalog broadcast will also land). Settle **Added to closet**. |

409 (already resolved or identity busy): do not advance the queue; keep the sheet; they can retry. 404: drop that match and `GET` pending again.

Do **not** treat resolve as “1 of 3”. Remaining is `pending.length` after a successful POST (the resolved id is gone).

---

## Product rules

1. **One ask at a time.** Never a stack of pending tiles. After resolve, settle copy, then the next pair.
2. **Banner under the toolbar.** Same chrome in All and Categories. Not a clothing section called Pending. Do not put this above the dock (that slot is processing).
3. **No queue count on the ask.** Title **Same {short name}?** / **Looks like one already in your closet**. Count only after a decision: **2 left to confirm** / **1 left to confirm**.
4. **Same / New live on the sheet**, not the banner. Banner tap opens the sheet.
5. **Catalog is confirmed pieces only.** A **new** resolve may add a tile; **same** does not duplicate.
6. **If remaining is 0** after resolve, hide the banner (no leftover count). Skip a settle flash on the last pair so the closet just returns to catalog.
7. **Do not poll.** Catch-up GET is the missed-ask path.
8. **Processing can show at the same time.** Dock chip / empty hang / hanger pulse unchanged.

---

## Closet screen

### Ask banner

Tappable. Two overlapping thumbs (probe then candidate) + title + subtitle + chevron.

> **Same white tee?**
>
> Looks like one already in your closet

Title uses a short candidate name: keep labels that already fit (`Same white tee?`); if the formatted label is long, use **color + kind** (`Same olive jacket?` not `Same olive green button-up jacket?`).

### Settle banner

Non-tappable. Check glyph + title + remaining line. Dwell **1.6s**, then show the next ask (or hide if empty).

> **Saved as the same piece** / **Added to closet**
>
> 2 left to confirm

### Sheet

Handle, **Same piece?**, one-line copy, two crops (New photo / In closet), **It's the same** / **It's new**.

Copy templates (fill with display name / kind from the pair):

- Tee-like: We spotted this on a new outfit. Is it the {name} already in your closet?
- Default: New outfit, familiar {name}. Same piece, or a second one?

### Empty / search miss

If the catalog is empty or filtered empty, the banner still sits under the toolbar when the queue is non-empty. Do not hide asks behind “Nothing hanging yet.”

---

## Flutter shape

Keep asks on [`ClosetManager`](../lib/core/managers/closet_manager.dart) next to identity chrome so bind/resume/reset stay in one place.

- [`ClosetApiService`](../lib/core/services/api_service/closet_api_service.dart): `getPendingMatches()`, `resolveMatch(id, decision)`.
- [`ClosetBrowseView`](../lib/pages/closet/closet_browse.dart): pinned sliver (or header slot) **below the resizing header / toolbar**, above the grid. Same in All and Categories.
- Sheet: modal bottom sheet, not a route.

**Not in v1**

- Rendering scores or “1 of 3”.
- A Pending category.
- Swipe-dismiss as same.
- Deep-link-only resolve screen (closet banner is enough; push still opens closet).
- Match realtime (none ships).
- Session hanging pill (still the last identity-progress item).

---

## Explicitly not this

Polling pending. Putting asks in the dock chip. Auto-resolving. Showing unconfirmed crops as masonry tiles.
