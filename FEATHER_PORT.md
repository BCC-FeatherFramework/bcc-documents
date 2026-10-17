# bcc-documents on Feather

**Status:** 1.0.0, code complete on 2026-10-18; release and offline flow tests
pending on the development server. This port is the first consumer of
`feather-licenses` (phase L3 of the
[Licenses master plan](https://github.com/FeatherFramework/feather-framework-docs/blob/main/feather-licenses/Feather_Licenses_Master_Plan.md)).

Licences move to feather-licenses, fees to feather-economy, document items to
feather-inventory, job rules to feather-jobs. No VORP, bcc-utils, oxmysql or
feather-menu (v1) code is left.

## Who owns what

| Upstream (VORP) | Feather |
|---|---|
| `bcc_documents` row per `charidentifier` + `doc_type` | `bcc_documents` per `character_id` (UUID) + `doc_type`: names, date of birth, gender, job label, photo. For a licence, `license_id` points at feather-licenses |
| `expire_date` string | Licence `expiresAt` in feather-licenses; status (valid, expired, suspended, revoked) read on every view |
| Hunting, mining, lumber, gold panning, weapon licences | feather-licenses definitions `hunting`, `mining`, `lumber`, `goldpanning`, `weapons`, owned by bcc-documents and registered on start from `Config.DocumentTypes[*].licenseKey` |
| ID card | Stays in bcc-documents: identity, not a licence |
| `character.removeCurrency` | Economy `Transfer` wallet to system sink, reasons `documents.purchase`, `documents.extend`, `documents.reissue`, `documents.photo` |
| `vorp_inventory` items, `canCarryItem` | feather-inventory stack items (one per character, `sql/install_items.sql`), delivered with `GrantCharacterItem` (works offline) |
| `Character.job == allowJob` / `AdminJob` | `allowJob` is a feather-jobs job key (`CheckAssignment`); Feather Admin staff (`Config.feather.adminStaffCapabilities` through feather-authority) may give any document |
| `nickname`, `age` | Not in Feather profiles: documents print the date of birth instead; no nickname |
| `bcc-utils` prompts, blips, peds | feather-toolkit |
| `feather-menu` | feather-menu-v2 through `client/feather/menu_v2.lua` |
| Net events with client-sent document data | Core RPCs; the server builds every document view from its own records |

## Orders

Every paid action is an order in `bcc_documents_orders`:

```text
pending -> Economy charge -> paid -> Licenses / record / item -> fulfilled
pending -> refused charge -> rejected
paid    -> later step failed -> review (money moved)
```

The Economy idempotency key and the Licenses request ID are the order ID, so a
retry never charges or issues twice. Console:

| Command | Purpose |
|---|---|
| `DocumentsOrdersReport` | Lists unresolved orders (pending, paid, review) |
| `DocumentsOrdersRetry <orderId>` | Runs an order again; a `review` order resumes after the payment. Works offline |
| `DocumentsOrdersResolve <orderId> <fulfilled\|rejected> <note>` | Closes an order by hand after staff settled it elsewhere; moves nothing |

## Behaviour changes from upstream

| Topic | Change |
|---|---|
| Extending | Adds the days to the current expiry (or to now when expired) instead of resetting to now + days, so paid time is never lost. At most `Config.feather.maxExtendDays` per purchase |
| Permanent documents | The extend button is hidden for documents with `expiryDays = 0` (upstream showed it for every type) |
| Weapon licence by command | The officer is recorded as the issuer; `paper` is needed when `Config.NeedItem` is on (upstream required two) |
| Showing a document | The server checks the distance and builds the view; the client cannot send document contents |
| Photo | https links only, at most `Config.feather.maxPhotoUrlLength` characters |
| Revoke | Revokes the licence in feather-licenses, deletes the record and takes every copy back |
| A licence revoked or suspended elsewhere (law) | The document shows it; a revoked licence can be bought again |
| Discord webhooks, version check | Removed; licence changes are audited by feather-licenses, orders in `bcc_documents_orders` |

## Trust and policy grants

| Resource | Setting | Entries |
|---|---|---|
| feather-licenses | `Config.Access` | `trustedReaders`, `trustedRegistrars`, `trustedIssuers`, `trustedAuditors` |
| feather-admin | `Config.servicePolicy['feather-licenses']` | `licenses.definition.manage`, `licenses.issue`, `licenses.revoke` |
| feather-economy | `Config.Access` | `trustedReaders`, `trustedProvisioners`, `trustedTransactors` |
| feather-jobs | `Config.Access` | `trustedReaders` |
| feather-authority | `Config.Access` | `trustedReaders` |

```lua
-- feather-admin/configs/service_policy.lua
Config.servicePolicy['feather-licenses'] = {
    ['bcc-documents'] = {
        ['licenses.definition.manage'] = true,
        ['licenses.issue'] = true,
        ['licenses.revoke'] = true
    }
}
```

Restart feather-licenses, feather-economy, feather-jobs, feather-authority and
feather-admin after changing them, then bcc-documents.

## Console tests

| Command | Purpose |
|---|---|
| `DocumentsReleaseSmokeTest` | Read-only: dev mode off, flow test absent, tables, items, licence definitions owned, Licenses/Jobs/Authority trust, Economy currency |
| `DocumentsFlowTest <characterUuid>` | DevMode only, moves money (the configured prices). Works with the character offline: buys an ID card and a hunting licence, extends it two days, reissues a lost copy, changes the photo, revokes both |

## Files

| File | Role |
|---|---|
| `server/feather/init.lua` | Results, RPC, notifications, characters, domain calls |
| `server/feather/economy.lua` | feather-economy boundary |
| `server/feather/licenses.lua` | feather-licenses boundary and definition setup |
| `server/feather/inventory.lua` | feather-inventory boundary |
| `server/feather/jobs.lua`, `authority.lua` | Job and staff checks |
| `server/services/migrations.lua` | `bcc_documents`, `bcc_documents_orders` |
| `server/services/documents.lua` | Records and document views |
| `server/services/orders.lua` | Paid workflows and reconciliation commands |
| `client/feather/*` | Core RPC, notifications, Menu v2 compatibility layer |

## Remaining work

1. Live test with two players: buy at the office, show a document, officer
   command (`giveweaponlicense <id>`) with a `doj` job.
2. bcc-legendaries checking the hunting licence through feather-licenses (L4).
