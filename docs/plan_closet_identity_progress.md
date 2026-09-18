# Closet identity progress

Locked product + Flutter plan for showing when background closet identity jobs are in flight. HTML mocks: [`closet-processing-preview.html`](./closet-processing-preview.html) (closet screen, including failed empty), [`closet-session-hanging-preview.html`](./closet-session-hanging-preview.html) (Hanging tag on the advice-thread look), and [`closet-nav-processing-preview.html`](./closet-nav-processing-preview.html) (dock badge off the closet tab).

Backend already ships this in stylens-lite-api:

- `GET /closet/identity/status` → `{ processing, queued, running, failed }`
- Realtime `closet-identity:{dbUserId}` / `closet_identity_updated` → same payload plus `phase: "started" | "settled"` (wave chrome only)
- Same channel / `closet_catalog_updated` → `{ reason: "identity", outfit_id, closet_item_ids }` when the browse catalog actually changed

`processing` is true while any identity job is `queued` or `running`. Failed jobs do not keep the indicator on. Progress broadcasts **once per wave** (idle → in-flight) and **once when the wave settles** (in-flight stayed 0 for ~20s). Never per photo. Catalog pings are a separate event, one per finished photo that mutated browse-visible items.

This note is the client UX we should implement. Do not implement until this slice is pulled.

---

## What we are building

After an outfit is tagged, identity work continues in the background. The closet can stay empty for a bit, then tiles land. Waiting signals, in this order:

1. **On the closet screen** — a processing empty state, a **failed empty** state if the wave settles with nothing to show, or a chip pinned just above the floating dock when the grid already has pieces.
2. **Off the closet tab** — a badge on the Closet hanger in the floating dock (Capture / History).
3. **Last — on the advice thread** — a tiny **Hanging** pill on the look photo. Session is a full-screen route with no dock, so this is the closet signal while they read advice.

The dock badge is how they know to come back. The closet screen is how they wait without thinking the closet is broken. The session pill is the handoff from Capture, and ships last.

---

## API contract (do not invent a second one)

Channel: `closet-identity:{User.id}` (same db id as `user-limits:{id}`). Two events. Do not mix them.

**Poll (chrome on cold start / resume)**

`GET /closet/identity/status`

```json
{ "processing": true, "queued": 2, "running": 1, "failed": 0 }
```

**Push — wave chrome**

Event: `closet_identity_updated`

```json
{ "processing": true, "queued": 2, "running": 0, "failed": 0, "phase": "started" }
```

```json
{ "processing": false, "queued": 0, "running": 0, "failed": 0, "phase": "settled" }
```

| Field | Client use |
| --- | --- |
| `processing` | Wave is still in flight. Show wait chrome. |
| `phase` | `started` → show wait chrome. `settled` → hide wait chrome. Do **not** wait for settled to refresh the catalog. |
| `queued` / `running` / `failed` | Keep on the model. **Do not render counts.** Same rule as pending-match banners (no “1 of 3”). |

**Push — catalog (live tiles)**

Event: `closet_catalog_updated`

```json
{ "reason": "identity", "outfit_id": "…", "closet_item_ids": ["…"] }
```

Always `fetchItems(forceRefresh: true)`. Do not render from `closet_item_ids` (no signed URLs on this ping). Ignore empty-id events if they ever arrive; the API does not send them.

Missed broadcasts are fine: GET status + items on login, channel subscribe/rejoin, resume, closet tab, and pull-to-refresh. No status poll and no item poll.

---

## Product rules

1. **Wave chrome, streaming catalog.** One indicator for the whole in-flight set. Tiles may already exist from finished jobs in that same wave — show them. Do not pulse placeholders for pieces that are not in `GET /closet/items` yet.
2. **Catalog does not wait for the wave.** Live path is `closet_catalog_updated` → `fetchItems(forceRefresh: true)`. Empty processing becomes the dock chip as soon as `items.isNotEmpty`. Hide wait chrome on `settled` (the ~20s quiet window is for the indicator, so it does not blink if another job starts). A last `fetchItems` on settle is only a catch-up. Do not run a periodic item poll as the live path.
3. **No job counts in copy.** “Hanging your pieces” / “Hanging a few more” — never “3 jobs” or “2 running”.
4. **Empty + processing is not first-run empty.** Do not show **Nothing hanging yet** while work is in flight. That copy is only for idle empty.
5. **Grid stays usable.** Processing is not a blocking overlay and not a fake skeleton closet.
6. **Dock badge only when Closet is not selected.** On the closet tab the screen chrome is enough. Do not double-indicate on the active hanger.
7. **Do not steal the pending-match slot.** Asks stay under the toolbar ([`closet-review-preview.html`](./closet-review-preview.html)). Processing on a non-empty closet docks **above the navbar**. Both can show at once.
8. **Failed empty only when they were waiting and nothing landed.** If wait chrome was up and `settled` leaves `items.isEmpty`, replace the wait empty with **Couldn’t hang that look** (Capture CTA back). Do not toast, do not push, do not key off cumulative `failed`. Partial miss (some tiles landed) stays silent.
9. **Do not flip `processing` locally on shutter.** Identity enqueue happens after outfit tagging, not at capture. Wait for GET / realtime.
10. **Session tag is temporary.** Lime pill on the latest look’s photo while `isProcessing`. Remove on `settled`. Never a permanent “In closet” stamp.

---

## Closet screen

Same header (Your Closet + search + All/Categories). Pending-match asks keep the slot **under the toolbar**. Processing on a filled closet does not.

### Empty + processing

Replace `ClosetEmptyState` (ghost rack + **Nothing hanging yet**).

Locked copy:

> **Hanging your pieces**
>
> We’re pulling them from your outfit. They’ll land here in a moment.

- Keep the three dashed ghost tiles, but give them a slow shimmer so they feel in-progress, not abandoned.
- Hide **Capture an outfit** while processing — this screen is wait-only until the first pieces land.
- Search / view mode stay; they just have nothing to filter yet.
- The moment the first item exists, leave this state even if the wave is still running.

### Empty + failed

Only this path: wait chrome was showing, the wave `settled`, catalog is still empty. Static ghost tiles (no shimmer). Capture comes back.

> **Couldn’t hang that look**
>
> We couldn’t pull pieces from your latest outfit. Capture it again and we’ll try once more.

Do not use this for first-run idle empty. Do not show it because GET `failed > 0` on a later visit.

### Non-empty + processing

Keep the masonry. Pin a **non-tappable** chip just above the floating dock (same 20px side inset, ~8px gap). It stays put while the grid scrolls.

> **Hanging a few more**
>
> From your latest outfit

Left glyph: small lime spinner (not catalog thumbs — we do not have the new tiles yet). Extra bottom inset so the last row clears the chip + dock.

Pull-to-refresh still refreshes the catalog. It does not cancel processing. `closet_catalog_updated` does the same job without a pull.

### Idle

No banner. Existing empty / grid / search-miss states unchanged.

---

## Dock badge (not on Closet)

When `processing == true` and the selected tab is Capture or History:

- 8px lime dot on the **top-right of the hanger**, with a soft pulse ring.
- Inactive hanger color stays as today (light on the green dock). The lime is the only extra.
- Semantics: `Closet, hanging pieces`.

Recommended treatment is in [`closet-nav-processing-preview.html`](./closet-nav-processing-preview.html) (pulse dot). Do not replace the icon with a spinner — it fights the tab bounce and is unreadable at 21px.

When they tap Closet, the badge disappears (tab is selected) and they see the screen states above.

---

## Session look tag

Advice (`/session/:id`) is outside the home shell — no floating dock. Put the closet signal on the look.

- Lime pill, **bottom-left** of the 200px session photo.
- Copy: **Hanging** plus a 10px spinner.
- Latest in-flight look only, while `isProcessing`.
- Non-tappable. Full-screen preview of the photo still works.
- Remove on `settled`. Tiles in Closet are the proof.
- Not on Capture shutter (identity has not started). Not on History 60px thumbs (busy overlay + hanger pulse are enough).

Mock: [`closet-session-hanging-preview.html`](./closet-session-hanging-preview.html).

---

## Flutter shape

`ClosetManager` already owns the catalog and is a root `ChangeNotifierProvider`. Put status there so the dock can read it without being on the closet route.

**Model** `ClosetIdentityStatus` — `processing`, `queued`, `running`, `failed`, optional `phase`.

**`ClosetApiService.getIdentityStatus()`** — `GET closet/identity/status`, no cache.

**`ClosetManager`**

- `bool get isProcessing`
- `bindUser(String dbId)` from the same `UserStateManager` path that calls `SubscriptionManager.initialize` (same db-id realtime pattern as `user-limits:`).
- One channel `closet-identity:$dbId`. Two `onBroadcast` subscriptions:
  - `closet_identity_updated` → wait chrome
  - `closet_catalog_updated` → `fetchItems(forceRefresh: true)`
- GET status + items on bind, channel `subscribed` / rejoin, app resume (`WidgetsBindingObserver`), closet tab visible, and pull-to-refresh.
- No periodic status poll. Subscribe/rejoin and resume are the missed-`settled` path.
- On `phase == started`: show wait chrome.
- On `phase == settled`: hide wait chrome, one last `fetchItems(forceRefresh: true)`.
- Do not hide wait chrome just because the first tile arrived, or just because a single GET returned `processing: false` (another job may still enqueue inside the quiet window).
- `reset()` on logout: leave the channel, clear status (mirror `SubscriptionManager`).

**UI**

- `ClosetBrowseView` — idle empty vs processing empty vs **failed empty**; overlay chip above the dock when `items.isNotEmpty && isProcessing`. Extra scroll padding so tiles clear the chip.
- `FloatingNavBar` — optional `closetProcessing`. `HomeShell` passes `manager.isProcessing && selectedIndex != 0`.
- Reduce motion: freeze the pulse / spinner; keep the static lime dot.
- Last: `MessageImageGallery` — lime **Hanging** pill, bottom-left on the latest look photo, while `isProcessing`. Remove on `settled`.

**Not in v1**

- Per-tile placeholders for incoming pieces.
- Rendering `queued` / `running` / `failed`.
- A settle toast (“Pieces are in”). Tiles arriving *is* the progress. Settled only dismisses wait chrome.
- Optimistic processing on capture.
- Putting processing in the pending-match banner slot.
- A failure or “closet ready” push. Style-advice and match-confirm pushes stay as they are.
- A permanent “In closet” stamp on look photos.

---

## Implementation phases

1. **Wire** — model, `getIdentityStatus`, parse tests.
2. **Manager** — bind / both realtime events / resume / hide chrome on settle. Unit tests with a fake API + fake `closet_identity_updated` and `closet_catalog_updated` streams.
3. **Closet screen** — empty processing, **failed empty**, docked chip on a filled grid. Widget tests for idle empty vs processing empty vs failed empty vs chip-on-grid (including with a pending-match banner).
4. **Dock** — badge when Closet is not selected. Widget test on `FloatingNavBar`.
5. **Lifecycle** — bind from `UserStateManager`; reset on sign-out.
6. **Last — session hanging pill** — lime **Hanging** pill on the latest look photo while processing. Widget test on `MessageImageGallery`. Mock: [`closet-session-hanging-preview.html`](./closet-session-hanging-preview.html).

---

## Explicitly not this

A loading skeleton pretending to be a closet. A spinner replacing the Closet tab icon. Showing **Nothing hanging yet** during a live wave. Surfacing failed-job counts.
