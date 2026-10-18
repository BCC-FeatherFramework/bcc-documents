## BCC Documents (Feather Framework)

> A document system for the Feather Framework: ID cards and licences for
> hunting, mining, lumber, gold panning and weapons.

This is the Feather Framework port of
[BryceCanyonCounty/bcc-documents](https://github.com/BryceCanyonCounty/bcc-documents),
maintained in [BCC-FeatherFramework](https://github.com/BCC-FeatherFramework).
Licences are recorded by `feather-licenses`, fees go through `feather-economy`,
and the documents are `feather-inventory` items. See
[FEATHER_PORT.md](FEATHER_PORT.md) for what changed.

## Features

- ID card with a photo you can change
- Licences for mining, hunting, lumber and gold panning, bought at the licensing office
- Weapon licence given by a job (by default `doj`) with a command
- Extend a licence for as many days as you want (up to a configured limit)
- Get a lost copy reissued, show a document to a nearby player, revoke your own

## Dependencies

```text
feather-mysql, feather-core, feather-character, feather-notify, feather-menu-v2,
feather-toolkit, feather-economy, feather-inventory, feather-jobs,
feather-authority, feather-licenses
```

## How to install

1. Copy `bcc-documents` to `resources/[bcc]/bcc-documents`.
2. Apply `sql/install_items.sql` to your database, then restart feather-inventory.
3. Add the trust entries and the service policy grant from
   [FEATHER_PORT.md](FEATHER_PORT.md#trust-and-policy-grants), and restart those resources.
4. Add `ensure bcc-documents` to `server.cfg`, after the Feather resources.
5. Run `DocumentsReleaseSmokeTest` in the server console.

The images in `imgs/` can be copied to your inventory's item images.

## Credits

Original resource by the [BCC Team](https://github.com/BryceCanyonCounty),
inspired by [mms-id](https://github.com/RetryR1v2/mms-id). The upstream
repository has no licence file, so this port adds none; the BCC Team's terms
apply.

Need help? Join the BCC Discord: https://discord.gg/VrZEEpBgZJ
