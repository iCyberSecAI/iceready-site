# ICE Ready Wallet pass

Builds `ice-ready-rights.pkpass` — a free Apple Wallet card carrying the
know-your-rights language, an attorney line, and an emergency contact line.

It is a **reference card, not identification.** It is not issued by any
government and proves nothing about who the holder is. The card says so on its
back, and the site copy says so too. Keep it that way.

## Why this exists

Apple Wallet now holds state mDLs and a passport-based Digital ID. That makes
Wallet the place people already look for "my documents." This pass puts ICE
Ready on that same screen, next to the state ID, for free — turning Wallet from
a competitor into a distribution channel.

## What you need

A paid Apple Developer account. There is no way around this: Wallet refuses
unsigned passes, and only Apple issues the certificate.

1. **A Pass Type ID.** Apple Developer → Certificates, Identifiers & Profiles →
   Identifiers → `+` → Pass Type IDs. Name it something like
   `pass.app.iceready.rights`.
2. **A Pass Type ID certificate** for that identifier. Create it in the same
   place, download the `.cer`, then export it from Keychain Access **together
   with its private key** as a `.p12`.
3. **The Apple WWDR intermediate certificate**, as PEM:
   ```
   curl -o AppleWWDRCAG3.cer https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
   openssl x509 -inform DER -in AppleWWDRCAG3.cer -out wwdr.pem
   ```
4. **Your Team ID** — the 10-character string in the top right of the developer
   portal.

## Build

Create `config.env` next to this README (it is git-ignored — do not commit it):

```sh
PASS_TYPE_ID=pass.app.iceready.rights
TEAM_ID=XXXXXXXXXX
PASS_CERT=/absolute/path/to/pass-cert.p12
PASS_CERT_PASS=the-p12-password
WWDR_CERT=/absolute/path/to/wwdr.pem
```

Then:

```sh
./build.sh
```

Output lands in `dist/ice-ready-rights.pkpass`. Email it to yourself and open it
on an iPhone to test — it should offer to add to Wallet.

Requires `openssl`, `zip`, and one of `sips` (macOS), ImageMagick, or Python
with Pillow for the icon resizing.

## Serving it from the website — read this before you publish

**GitHub Pages cannot serve this file correctly.** Wallet only recognizes a pass
when it arrives with the MIME type `application/vnd.apple.pkpass`. GitHub Pages
serves unknown extensions as `application/octet-stream`, so iOS will download it
as a dead file instead of opening Wallet. There is no way to set response
headers on GitHub Pages.

The site is on GitHub Pages today (see `CNAME`), so publishing the pass needs one
of these:

- Put the pass behind Cloudflare (a Transform Rule setting the `Content-Type`
  header on `/passes/*`), or
- Host `/passes/` on Netlify, Vercel, or Cloudflare Pages, which all let you set
  the header in config, or
- Serve it from the app instead of the website.

Until one of those is in place, the "Add to Apple Wallet" button on
`wallet.html` and `es/wallet.html` is commented out. Uncomment both when the
pass is built and served with the right header.

## Editing the card

`pass.json` holds all the copy. The `backFields` array is the long-form text on
the back of the card. Two rules:

- Keep the "This is not identification" field first. It is the first thing
  someone reads when they flip the card.
- Keep the "Not legal advice" field. General rights information is fine; telling
  someone what to do in their case is not.

The attorney and emergency contact fields ship as `—` because the pass is signed
once and handed to everyone. Wallet passes are static — a holder cannot type
into them. If per-person contact details matter, that belongs in the app, not
here.
