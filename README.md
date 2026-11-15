# developer.vpnhood.com

The source of [developer.vpnhood.com](https://developer.vpnhood.com): its look, its pictures, and the script that
builds it with [DocFX](https://dotnet.github.io/docfx/). The text is not here: each part is read from where it is
written, in [VpnHood](https://github.com/vpnhood/VpnHood), so nothing is written twice.

- **Start here:** the pages `build.ps1` lists in `$articles`, from VpnHood's `docs/`. Only those: the rest of `docs/`
  is maintainers' notes, not product documentation.
- **Libraries:** each package's `README.md`, or, for a package without one, a page made from its project.
- **API reference:** the doc comments of every package whose project sets `VhApiDocsComplete`, the gate that fails
  its build on a missing comment, plus VpnHood.Net.Proxies from its own repo.

`categories.psd1` holds the four big categories (Networking, VPN Core, App Logic, App UI): what each is for, its
picture, and its real-world scenarios. The home page shows each as a card, and the API reference's front page as a
section with its scenarios. `images/` holds the site's pictures; a picture of an app made from the template shows a
made-up brand, never one of VpnHood's own apps.

## When it builds

`.github/workflows/build.yml` builds the site from VpnHood's `develop`:

- on every push to this repo's `main`;
- after every release: VpnHood's release scripts (`pub/*/PublishByGithub.ps1`) start it with the releaser's own
  GitHub login once the release has bumped VpnHood's version, so VpnHood holds no credential for this repo;
- by hand, from the Actions tab, for any branch, tag or commit of VpnHood.

Each run publishes the site to GitHub Pages, at developer.vpnhood.com: the domain is this repo's Pages setting, and
its DNS a CNAME to `vpnhood.github.io` at Cloudflare, proxied as www.vpnhood.com's is.

## Build it locally

Next to clones of [VpnHood](https://github.com/vpnhood/VpnHood) and
[VpnHood.Net.Proxies](https://github.com/vpnhood/VpnHood.Net.Proxies), with the workloads the packages need
(`android`, `ios`, `tvos`, `maui-android`, `maui-windows`):

```powershell
pwsh ./build.ps1 -WorkDir $env:TEMP/vh-developer-site
dotnet docfx serve $env:TEMP/vh-developer-site/_site
```

`-SkipMetadata` keeps the last run's API metadata, which is the slow part, when only pages changed.

`template/layout/_master.tmpl` is DocFX's own layout with a canonical link added: compare it with the new DocFX's
`templates/modern/layout/_master.tmpl` when `.config/dotnet-tools.json` moves to another version.
The layout also links the site's icons, all in `images/`: `favicon.svg` and `favicon.ico`, copies of www.vpnhood.com's,
for the browser tab, and for an installed site `site.webmanifest`, `icon-192.png`, `icon-512.png` and
`apple-touch-icon.png`, www's icon with a DEV ribbon, the apple-touch icon on white, as iOS fills a transparent
corner with black. Those three are exported by the team's artwork script that draws the icon; replace them from a new
export, never edit them by hand.
`template/public/main.js` sets DocFX's `showLightbox`, so a click on the site's heroes and art opens nothing, while a
picture in a page's own text still opens alone at full size. It also lets a long dotted name wrap after its dots, and
gives each table cell its column's name, so that on a phone `main.css` shows every table's rows as cards.

## Forge hero artwork

The home page and the Build your VPN app guide open with the same banner, across the window's whole width under the top
bar, above the page's menus: the title on the dark left side, lined up with the page, and the scene on the right. The
forge, whose left side is an empty wall, takes the whole width; the casting scene fills the banner's height and stays
whole. `build.ps1`'s `Add-Hero` gives a page its banner; each scene says how much of its left side is empty, so the copy
never covers its figures.

The selected master is `developer-forge-banner-refined-hands.png`; it and its generation prompt are kept outside this repository.
Run `python tools/export-forge-hero.py PATH_TO_MASTER.png` (Pillow required) to export the desktop
and mobile WebP images used by the home page. Keep the master unchanged; the exporter only resizes
and compresses it.

## Casting article artwork

The Build your VPN app guide shows a separate casting scene in its banner, beside its title, followed by the existing
step illustrations. The master, `build-your-app-casting-soft-forearms.png`, and its generation prompt are kept outside this repository.
Run `python tools/export-casting-hero.py PATH_TO_MASTER.png` (Pillow required) to export the desktop and small WebP
images. Keep the master unchanged; the exporter only resizes and compresses it. The page shows the complete scene
at every width so both workers, the pour, and the mold stay visible.
