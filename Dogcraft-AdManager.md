# DCAM — Dogcraft Ad Manager

Players advertise their shops and businesses, in game and on the website, and
pay for it out of the in-game economy.

Two halves that do very different jobs:

| | |
|---|---|
| **Website** (`Dogcraft-Website`) | Everything about *creating* an ad, and every decision. Auctions, pricing, moderation, reporting, the ledger. |
| **Plugin** (this repo) | Funds accounts from in-game wallets, renders ads in chat, processes clicks, delivers notifications. |

The plugin never runs an auction, prices anything, moderates text, or writes to
the ledger. It reports what happened and asks the website to charge. That split
is deliberate: business rules live in one place instead of being half-implemented
in Java and PHP and drifting apart. It also means a compromised backend can't
reach the money — the worst it can do is make requests the website validates.

---

## What an ad is

Three advertiser-controlled fields, and nothing else:

- **Subject** — a shop they own, or their business.
- **Contact** — business ads only; an officer, picked from a dropdown.
- **Tagline** — optional, 100 visible characters, filtered.

Everything else — the creative, the icon, the destination — is derived from live
data in the shops or businesses database at render time.

**That derivation is the whole security model.** There is no advertiser-supplied
destination anywhere in the system, so trap teleports and rug-pull links are
structurally impossible rather than merely filtered. A renamed shop, a moved
chest or a repriced item fixes itself with no edit.

It also means an ad with no tagline has nothing to moderate, so it goes live
immediately. Most ads take that path.

### Where an ad can run

| Slot | Surface | Priced | Notes |
|---|---|---|---|
| `shop_finder_featured` | web | per placement | Two promoted cards above shop search results |
| `web_home_card` | web | CPM | Home page, under the announcement |
| `web_profile_sidebar` | web | CPM | User profile |
| `web_footer_text` | web | CPM | One line, every page |
| `chat_welcome` | in game | CPC | Per player, under frequency caps |
| `chat_broadcast` | in game | CPC | Every online player, once an hour |

Slots are rows in `dam_slots`. Adding one on a new server is an insert plus one
plugin refresh — no deploy. Adding a new slot *type* needs plugin code, which is
why the type field is a fixed list.

### What a click does

Depends on the subject, not the slot.

**Shop ad → teleport.** The viewer pays a fee; the advertiser pays the CPC. The
fee is the anti-fraud mechanism — it exceeds the minimum bid, so a fraudulent
click costs the attacker more than the advertiser they're attacking. Billed only
on a teleport that actually starts, and refunded if a cross-server hop stalls.

**Business ad → a lead.** A fixed-template message to the contact, free to the
viewer. That removes the fee-based deterrent entirely, so per-viewer caps replace
it. Billing follows the broker confirming delivery, so a repeat click inside the
dedup window produces no message and therefore no charge.

**Web click → nothing but navigation.** Web placements are sold per view, so the
click is recorded for the advertiser's stats and never billed.

---

## Plugin

### Requirements

- Paper **26.2**, Java **25**
- **Hard deps:** DogcraftEconomy, Dogcraft-PlayerMessager — without a wallet
  there is no product, and the broker already owns cross-server routing, offline
  queueing and login replay
- **Soft deps:** DogcraftBusinesses, DogcraftHomes — reflection-loaded, so the
  plugin starts cleanly without them. Missing Businesses costs business funding;
  missing Homes costs shop-ad teleports

### Install

Build with `./gradlew build`, drop the jar in `plugins/` on **every backend**.
There is nothing to install on the proxy.

`plugins/Dogcraft-AdManager/config.yml` has three keys and no database
credentials of any kind:

```yaml
dcam:
  api-base: "https://dogcraft.net/api/dcam"
  api-token: "<sanctum token, see below>"
  server-uuid: "auto"
```

Fees, caps, cooldowns, word lists and slot definitions all come from the website
so you retune the network once instead of editing every backend.

> **Leave `server-uuid` as `auto`.** It reads NetworkSwitch's `server_id.conf`.
> Copying this file between backends with an explicit UUID makes every server
> report the same identity — server targeting stops working and events are
> misattributed, both silently. This is the most likely deployment mistake.

### Commands

```
/dcam deposit  <amount> [business]
/dcam withdraw <amount> [business]
/dcam balance           [business]
/dcam campaigns
/dcam reload-config
```

Creating ads lives on the website, where a shop picker and a live preview are
possible. The game handles the one thing the website can't: moving money in and
out of a wallet only the plugin can touch atomically.

Business funding needs `WITHDRAW` on the business, checked against the live
`BusinessRegistry` rather than the website's mirror — a demotion should take
effect immediately, not on the next cache cycle.

### Proxy networks

- **Frequency caps are held on the website**, not per backend. Changing server
  fires `PlayerQuitEvent` on the origin, so per-backend caps reset on every hub
  trip — ordinary behaviour, not an attack. Same for the click cooldown and the
  hourly rate limit.
- **All backends must share one Redis** with the website, or each runs its own
  auction and different servers show different ads in the same hour.
- **The hourly broadcast fires per backend**, each to its own players. A player
  is on exactly one backend, so nobody sees it twice, and it bills on click so N
  backends don't multiply cost. It fires at `:05`, not `:00` — that's when every
  other scheduled job on a network runs. Keep backend clocks in sync.

---

## Website

### Install

1. Add the `dam` connection to `.env`:
   ```
   DB_DAM=mysql://user:pass@host:3306/dam
   ```
2. `php artisan migrate` — creates the schema, seeds settings, word lists,
   generated-copy templates and the six slots.
3. `npm run build` (client **and** SSR — this project has both).
4. `php artisan storage:link` if it isn't already, for business logos.
5. Grant the permission nodes below.
6. Confirm `schedule:run` cron exists — the nightly reconciliation is registered
   at `03:20` and nothing complains if it never runs.

### `CACHE_STORE=redis` is mandatory

The auction caches its decision for a few seconds and invalidates by cache tag.
`file` and `database` stores don't support tags, so invalidation degrades —
meaning **an ad you pause during an incident keeps serving until the TTL
expires**. Redis is also the fast path for frequency caps, impression dedup and
click-token replay guards; those have MySQL fallbacks, but auction invalidation
degrades to *wrong* rather than slow.

### The plugin's API token

One token, shared by every backend. It authenticates as a real user, and
`createToken()` sets no ability restrictions — so the token carries that
account's full authority across every API route, in plaintext, on every backend.

**Mint it from a dedicated service account whose only node is `dam.plugin`.** Not
from an admin's account.

```bash
php artisan tinker --execute="echo App\Models\User::where('uuid','<service-uuid>')->firstOrFail()->createToken('dcam-plugin')->plainTextToken;"
```

Two things that will bite:

- Permissions resolve from the **linked Minecraft identity**, not the website
  row. An unlinked account has no permissions and will 401.
- `hasPermission()` is wildcard-matched, so a rank holding `*` or `dam.*`
  already satisfies `dam.plugin`. That's why an admin's token "just works", and
  why it's the wrong account to use.

Verify before touching a backend:

```bash
curl -i -s -H "Authorization: Bearer YOUR_TOKEN" -H "Accept: application/json" https://dogcraft.net/api/dcam/config
```

| Response | Meaning |
|---|---|
| `200` | working |
| `401` | token wrong, revoked, or the account isn't linked |
| `404` | token valid, but the account lacks `dam.plugin` |
| `302` → `/404` | wrong host |

Rotation is issue → deploy → revoke. Revoking first takes every backend down
until the new token is out.

---

## Permission nodes

### In game

| Node | Default | Does |
|---|---|---|
| `dcam.use` | true | `/dcam deposit`, `withdraw`, `balance`, `campaigns` |
| `dcam.view` | true | Receive in-game ads. **Revoke to opt a player or a whole rank out** |
| `dcam.admin` | op | `/dcam reload-config` |

### API

| Node | Does |
|---|---|
| `dam.plugin` | The only node `/api/dcam/*` checks. Give it to the service account and nothing else |

### Advertiser side

No nodes. Any linked player can advertise their own shops; business ads are
gated on being an **officer** of that business, derived from the roster rather
than from website permissions.

### Admin — one node per page

Each page has its own node, so a reviewer can be given the review queue without
also getting the config screen that changes the click fee network-wide.

| Node | Grants |
|---|---|
| `admin.view` | Required for `/admin` at all — everything below needs it too |
| `admin.dam.overview` | `/admin/dcam` — KPIs, DCD sink report, stranded accounts, recent admin actions |
| `admin.dam.ads` | `/admin/dcam/ads` and the advertiser drill-down — every campaign running, with live previews |
| `admin.dam.review` | `/admin/dcam/review` — tagline queue, **and approving/rejecting them** |
| `admin.dam.logos` | `/admin/dcam/logos` — business logo queue, **and approving/rejecting them** |
| `admin.dam.fraud` | `/admin/dcam/fraud` — rejected clicks by reason and by ad |
| `admin.dam.slots` | `/admin/dcam/slots` — slot CRUD |
| `admin.dam.inventory` | `/admin/dcam/inventory` — house-ad pools, fill rate, house-ad toggles |
| `admin.dam.config` | `/admin/dcam/config` — fees, caps, word lists, generated ad copy |

Two write actions are riskier than looking, so they need a node **on top** of the
page's:

| Node | Grants |
|---|---|
| `admin.dam.campaigns` | Pause, resume, reject, bulk-act, ban and unban advertisers |
| `admin.dam.adjust` | **Edit an advertiser's balance.** Separate on purpose: pausing an ad is reversible, moving money isn't |

Nav links you can't open are hidden rather than shown and 404'd.

> **Upgrading:** viewing every page used to require only `admin.dam`. That node
> alone now grants nothing. Grant **`admin.dam.*`** for a full DCAM admin, or the
> individual nodes for narrower roles. Wildcards match, so `admin.dam.*` covers
> every node including future ones.

### Related, not DCAM's

| Node | Grants |
|---|---|
| `admin.businesses` | Sensitive business sections, used by the business portal |

---

## Moderation

Six layers, applied to every advertiser-written tagline and to staff-written
house copy and business page text — staff typo too, and an exemption would be
the one route by which unfiltered text reaches players.

1. **Structural** — length, charset, control characters. Rejected outright.
2. **Normalise** — lowercase, fold leetspeak, strip punctuation, collapse
   repeats. `F.U.C.K`, `f u c k` and `fuuuck` all become one string.
3. **Blocked terms** — reject.
4. **Patterns** — URLs outside `dogcraft.net`, and similar. Reject.
5. **Flagged terms** — allowed, but pinned to the top of the review queue.
   "Dogcraft's best prices" is fine, "official staff shop" probably isn't, and no
   regex tells them apart.
6. **Human review** — anything flagged, and anything with custom text.

Terms match from a **word boundary with a free tail**: `fuck` catches "fucking"
but not "Scunthorpe". Terms shorter than four characters after normalisation are
whole-word only — doubled letters collapse, so `coon` becomes `con`, which would
otherwise prefix "contact".

Load a fuller list at deploy time:

```bash
php artisan dcam:import-blocklist wordlist.txt --dry-run
php artisan dcam:import-blocklist wordlist.txt
```

---

## Money

Every DCAM charge **destroys currency** — there is no treasury it lands in. The
sink report on `/admin/dcam` is the only view of the economic pressure the ad
system applies, and the number to check before changing a fee.

- **CPM** accrues per view at `bid / 1000`, charged once the accrued amount
  reaches a cent. Low bids batch so views aren't rounded away.
- **Featured** bills per view.
- **CPC** bills on a teleport that starts, or a lead the broker accepted.
- **Self-views and self-clicks are never billed**, and are recorded separately so
  an advertiser testing their own ad sees it register instead of assuming the ad
  is broken.

The nightly reconciliation (`03:20`) pauses campaigns whose subject moved out
from under them, flags accounts whose owner no longer exists, and prunes the
tables that would otherwise grow forever. **Nothing in it moves a balance** — a
stranded account is flagged for a human, because that money belongs to somebody
and picking a recipient automatically would be guessing.

---

## Business pages

Business ads land on `/business/{uuid}`, which is **public** — most of the
audience is logged out.

A stranger sees the name, owner, officers, shops, and whatever officers wrote.
They do not see the balance, plain employees, shareholders, share structure,
transactions or corporate history. The public payload is built from scratch
rather than by masking the members' one, so a field added there can't become
public by omission.

Officers can set a headline, an About blurb, section toggles and a logo. Uploaded
logos are **re-encoded to WebP and only the WebP is kept** — smaller, one
predictable format, and EXIF (including GPS) is dropped. They stay unapproved
until staff review them, because they're public the instant they appear.

---

## Testing

```bash
./vendor/bin/phpunit tests/Feature/DAM        # website
./gradlew build                               # plugin
```

The suite runs against separate `test_*` schemas. That isolation is load-bearing:
the connections are built from URL env vars, so `DB_DATABASE=testing` alone
doesn't reach them and the suite used to run `RefreshDatabase` against the
development databases and wipe them.

---

## Layout

```
Dogcraft-AdManager/
  src/main/java/net/dogcraft/dogcraftAdManager/
    api/       HTTP client
    command/   /dcam
    config/    bootstrap config + remote settings
    hook/      Economy, PlayerMessager, Businesses, Homes
    notify/    notification outbox drainer
    serve/     ad rendering, slots, clicks, hourly broadcast
  docs/
    dcam-plan-v2.md      the design, and why
    deploying-dcam.md    deployment runbook
    filter.txt           starter word list

Dogcraft-Website/
  app/Services/DAM/      auction, billing, moderation, reporting, reconciliation
  app/Http/Controllers/
    Api/DAM/             the plugin's endpoints
    DAM/                 advertiser dashboard
    Admin/DAM/           staff pages
  resources/js/Pages/DAM/, Admin/DAM/
  tests/Feature/DAM/
```
