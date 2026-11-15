<#
.SYNOPSIS
Builds developer.vpnhood.com into a folder outside the repos.

.DESCRIPTION
The site's text is VpnHood's own, read from a clone of vpnhood/VpnHood next to this repo; this repo adds the look, the
pictures and the categories. The site has four parts:
- Start here: the hand-written pages on the allow-list below, copied from VpnHood's docs/. Never a glob: the rest of
  docs/ is maintainer notes, not product documentation. A link to a page left out goes to its copy on GitHub.
- Samples and templates: the app template and the samples, each a repository of its own, from its README.
- Libraries: a page for every package - its README, or, for a package without one, a page made from its project: what
  it does, how to add it, its API, and which of our packages it depends on and which use it.
- API reference: every public member, from the doc comments.

A package is on the site once its project sets VhApiDocsComplete, the gate that fails its build on a missing doc
comment, so no undocumented page goes public. VpnHood.Net.Proxies, from its own repo, joins Networking. Packages group
by their folder (Net, Core, AppLib, AppUi), then by feature: the third segment of their name.

.EXAMPLE
pwsh ./build.ps1
# then, from this repo (where the tool manifest is): dotnet docfx serve <WorkDir>/_site
#>
param(
    # where the site is generated; nothing is written into the repos
    [string]$WorkDir = (Join-Path ([IO.Path]::GetTempPath()) "vh-developer-site"),
    # a clone of vpnhood/VpnHood: its packages, their READMEs, and docs/
    [string]$VpnHoodRoot = (Join-Path $PSScriptRoot "../VpnHood"),
    # a clone of vpnhood/VpnHood.Net.Proxies
    [string]$ProxiesRoot = (Join-Path $PSScriptRoot "../VpnHood.Net.Proxies"),
    # clones of vpnhood/VpnHood.App.Samples and vpnhood/VpnHood.App.Template, for Samples and templates
    [string]$SamplesRoot = (Join-Path $PSScriptRoot "../VpnHood.App.Samples"),
    [string]$TemplateRoot = (Join-Path $PSScriptRoot "../VpnHood.App.Template"),
    [string]$BaseUrl = "https://developer.vpnhood.com/",
    # keep the last run's API metadata, when only the pages changed
    [switch]$SkipMetadata
)

$ErrorActionPreference = "Stop"
$vpnHood = (Resolve-Path $VpnHoodRoot).Path
$src = Join-Path $vpnHood "src"
$ProxiesRoot = (Resolve-Path $ProxiesRoot).Path
$SamplesRoot = (Resolve-Path $SamplesRoot).Path
$TemplateRoot = (Resolve-Path $TemplateRoot).Path
$githubBlob = "https://github.com/vpnhood/VpnHood/blob/develop/"

# the four big categories, with their pictures and real-world scenarios
$categories = @((Import-PowerShellDataFile (Join-Path $PSScriptRoot "categories.psd1")).Categories | ForEach-Object { [pscustomobject]$_ })

# kept off the site (owner, 2026-11-08); it keeps its doc comments and its NuGet package
$excluded = @("VpnHood.Net.Http3")

# the hand-written pages, in reading order: files of docs/, never a glob. A page's Hero is a picture of images/ that the
# site shows in the page's banner with its title, as the home page shows the forge; its Steps are a picture for each item
# of its first numbered list, which the site shows as steps. The page on GitHub goes without them, so VpnHood keeps no
# pictures for the site.
$articles = @(
    [pscustomobject]@{ File = "build-your-app.md"; Title = "Build your VPN app"
        Description = "Build your own VPN app for Android, iOS, Windows and Linux from VpnHood.App.Template, on VpnHood's NuGet packages."
        # the complete scene at every width, so both workers, the pour and the mold stay in sight; its furnace is a tenth
        # of its width from its left edge
        Hero = @{ Image = "images/hero-casting.webp"; Small = "images/hero-casting-small.webp"; Width = 2160; Height = 720
            Alt = "A hooded woman and a craftsman pour glowing metal into a mold in a stone workshop"; Ratio = "3 / 1"; Focus = "center"
            Clear = "0.1" }
        Steps = @(
            @{ Art = "images/step-template.svg"; Alt = "Use this template, on VpnHood.App.Template's GitHub page, makes a repository of your own" }
            @{ Art = "images/step-yours.svg"; Alt = "Your repository's app folder: app.props, appsettings.json, branding and icons" }
            @{ Art = "images/step-build.svg"; Alt = "dotnet build makes the app for Android, iOS, Windows and Linux" }) }
    # how much of the app you write yourself: the whole app above, then your own screens, then the engine alone (owner,
    # 2026-11-15: "I'm okay with 1 and 2")
    [pscustomobject]@{ File = "use-the-app-logic.md"; Title = "Your own screens over the app's logic"
        Description = "Put screens of your own over VpnHood's app logic, a whole VPN app without its UI: start it, connect, and show its state through the app's API." }
    [pscustomobject]@{ File = "use-the-engine.md"; Title = "Use the VPN engine in your own app"
        Description = "Connect with VpnHood's VPN engine from your own app: in your own process on Windows, or through the VPN service on Android." }
    [pscustomobject]@{ File = "run-a-server.md"; Title = "Run a VPN server from your own code"
        Description = "Run VpnHood's server engine in a .NET program of your own, with access keys kept in files: start it, and make a key a client connects with." }
    [pscustomobject]@{ File = "app-startup.md"; Title = "How a VpnHood app starts"
        Description = "How a head starts a VpnHood app: who the app is, its options with its store's providers, and what the host builds from them on Android, iOS, Windows and Linux." }
    [pscustomobject]@{ File = "client-architecture.md"; Title = "VpnHood Client Architecture"
        Description = "A VpnHood app is a head over three layers - the UI, the app's logic and the VPN engine - which meet at two contracts; which part to use for what you build." }
    [pscustomobject]@{ File = "vpn-engine.md"; Title = "How the VPN engine works"
        Description = "How VpnHood's VPN engine takes the adapter the platform makes, and how each packet travels between the adapter, the tunnel and the server." }
)

function Read-Text([string]$path) { [IO.File]::ReadAllText($path).TrimStart([char]0xFEFF) }

function Get-Anchor([string]$title) { ($title.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-") }

function ConvertTo-Html([string]$text) { [Net.WebUtility]::HtmlEncode($text) }

function Write-Text([string]$path, [string]$text) {
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
}

# A package's group (categories.psd1): its category's group whose Segment is the third segment of its name
# (VpnHood.Net.<Segment>...), so a project stays with the projects under it
function Get-Group([string]$name) {
    $key = "$($categoryOf[$name])|$($name.Split('.')[2])"
    if ($groupOfSegment.ContainsKey($key)) { return $groupOfSegment[$key] }
    $null
}

# a package's group by name; one in no group shows as its name's third segment, after the groups
function Get-Feature([string]$name) {
    $group = Get-Group $name
    if ($group) { $group.Name } else { $name.Split(".")[2] }
}

# [(Name, Items)] from one category's (Feature, Item) pairs: its groups first, in their order, then the rest by name. The
# order is the category's own, as each layer has a group named Abstraction.
function Group-ByFeature([string]$category, $pairs) {
    $order = @($groups | Where-Object Category -eq $category | ForEach-Object Name)
    @($pairs) | Group-Object Feature |
        Sort-Object @{ Expression = { $i = $order.IndexOf($_.Name); if ($i -lt 0) { $order.Count } else { $i } } }, Name |
        ForEach-Object { [pscustomobject]@{ Name = $_.Name; Items = @($_.Group | ForEach-Object Item) } }
}

function Get-Description([string]$csproj) {
    $match = [regex]::Match((Read-Text $csproj), "<Description>(.*?)</Description>", "Singleline")
    if ($match.Success) { ($match.Groups[1].Value -replace "\s+", " ").Trim() } else { "" }
}

# the names of the projects and packages a project references
function Get-References([string]$csproj) {
    [regex]::Matches((Read-Text $csproj), '<(?:ProjectReference|PackageReference)\s+Include="([^"]+)"') | ForEach-Object {
        $include = $_.Groups[1].Value
        if ($include.EndsWith(".csproj")) { [IO.Path]::GetFileNameWithoutExtension($include.Replace("\", "/")) } else { $include }
    }
}

function ConvertTo-FrontMatter($values) {
    $lines = foreach ($key in $values.Keys) { "${key}: '$($values[$key] -replace "'", "''")'" }
    "---`n$($lines -join "`n")`n---`n`n"
}

# A page's banner, which the layout draws across the window's whole width under the top bar, above the page's menus,
# alike on every page that has one (owner, 2026-11-14: "they just don't well organize and don't match together"): the
# page's title, with its lead and links if it has them, on the dark left side, and the scene at the banner's full height
# on the right; a scene whose left side is an empty wall takes the whole width instead (ArtWidth "100cqw"), cropped at
# Position. The copy runs over the scene no further than Clear, the share of the scene's width that is empty at its
# left. Below 992px the scene goes above the title, cropped to Ratio around Focus. The keys go into the front matter.
function Add-Hero($front, [string]$heading, $hero, [string]$lead = "", [string]$actions = "") {
    $values = [ordered]@{ vhHeroHeading = $heading; vhHeroImage = $hero.Image; vhHeroSmall = $hero.Small
        vhHeroWidth = $hero.Width; vhHeroHeight = $hero.Height; vhHeroAlt = $hero.Alt; vhHeroLead = $lead
        vhHeroActions = $actions; vhHeroArtWidth = $hero.ArtWidth ?? "300cqh"; vhHeroPosition = $hero.Position ?? "center"
        vhHeroClear = $hero.Clear ?? "0.1"; vhHeroRatio = $hero.Ratio ?? "3 / 1"; vhHeroFocus = $hero.Focus ?? "center" }
    foreach ($key in $values.Keys) { if ($values[$key]) { $front[$key] = $values[$key] } }
}

# the path a relative link in <dir> names, from VpnHood's root
function Resolve-RepoPath([string]$dir, [string]$target) {
    $parts = [Collections.Generic.List[string]]::new()
    foreach ($segment in "$dir/$target".Split("/")) {
        if ($segment -eq "" -or $segment -eq ".") { continue }
        if ($segment -eq "..") { if ($parts.Count) { $parts.RemoveAt($parts.Count - 1) }; continue }
        $parts.Add($segment)
    }
    $parts -join "/"
}

# the uid a code name in a page stands for: its full name, the same without "VpnHood.", or a short name only one has
function Find-Uid([string]$name) {
    if ($uids.Contains($name)) { return $name }
    if ($uids.Contains("VpnHood.$name")) { return "VpnHood.$name" }
    if ($shortUid.ContainsKey($name) -and $shortUid[$name]) { return $shortUid[$name] }
    $null
}

# A page's code names - `Name` in backticks, outside code blocks and headings - become links to their API pages. The
# page stays plain on GitHub and nuget.org, where it is read too; only the site's copy links.
function Add-ApiLinks([string]$markdown) {
    $fenced = $false
    $lines = $markdown -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*(```|~~~)') { $fenced = -not $fenced; continue }
        if ($fenced -or $lines[$i] -match '^\s*#') { continue }
        $lines[$i] = [regex]::Replace($lines[$i], '(?<![\[`])`([A-Za-z_][A-Za-z0-9_.]*)`(?![`\]])', {
            param($match)
            $uid = Find-Uid $match.Groups[1].Value
            if ($uid) { "[$($match.Value)](xref:$uid)" } else { $match.Value }
        })
    }
    $lines -join "`n"
}

function Invoke-Docfx([string[]]$arguments) {
    Push-Location $PSScriptRoot  # where the tool manifest is
    try {
        dotnet docfx @arguments
        if ($LASTEXITCODE) { throw "docfx $($arguments[0]) failed" }
    }
    finally { Pop-Location }
}

# the page of a package without a README: what it does, how to add it, its API and its neighbours
function New-PackagePage($project, [string]$description, $namespaces, $dependsOn, $usedBy) {
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("# $($project.Name)"); $lines.Add("")
    if ($description) { $lines.Add($description); $lines.Add("") }
    $lines.Add('```bash'); $lines.Add("dotnet add package $($project.Name)"); $lines.Add('```')
    if ($namespaces) {
        $lines.Add(""); $lines.Add("## API"); $lines.Add("")
        foreach ($namespace in ($namespaces | Sort-Object)) { $lines.Add("- <xref:$namespace>") }
    }
    foreach ($section in @([pscustomobject]@{ Title = "Depends on"; Names = $dependsOn }, [pscustomobject]@{ Title = "Used by"; Names = $usedBy })) {
        $names = @($section.Names | Where-Object { $_ } | Sort-Object)
        if (-not $names) { continue }
        $lines.Add(""); $lines.Add("## $($section.Title)"); $lines.Add("")
        foreach ($name in $names) { $lines.Add("- [$name](../$($categoryOf[$name])/$name.md)") }
    }
    ($lines -join "`n") + "`n"
}

# --- the packages
$projects = @(
    foreach ($category in $categories) {
        foreach ($csproj in Get-ChildItem "$src/$($category.Folder)/*/*.csproj" | Sort-Object Name) {
            $name = $csproj.BaseName
            if ($excluded -contains $name -or (Read-Text $csproj.FullName) -notmatch "<VhApiDocsComplete>\s*true\s*<") { continue }
            $readme = Join-Path $csproj.DirectoryName "README.md"
            [pscustomobject]@{ Category = $category.Key; Name = $name; Csproj = $csproj.FullName
                Readme = $(if (Test-Path $readme) { $readme } else { $null }) }
        }
        if ($category.Key -eq "net") {
            [pscustomobject]@{ Category = "net"; Name = "VpnHood.Net.Proxies"
                Csproj = Join-Path $ProxiesRoot "src/VpnHood.Net.Proxies/VpnHood.Net.Proxies.csproj"; Readme = Join-Path $ProxiesRoot "README.md" }
        }
    }
) | Sort-Object @{ Expression = { $categories.Key.IndexOf($_.Category) } }, @{ Expression = { $_.Name.ToLowerInvariant() } }
$categoryOf = @{}
foreach ($project in $projects) { $categoryOf[$project.Name] = $project.Category }
Write-Host "$($projects.Count) packages"

# --- the groups: each category's, in their order. A group is one project and the projects under it, those whose name's
# third segment is its Segment, so the docs keep the projects' hierarchy (owner, 2026-11-13: "in doc hirarchy, keep
# project hirarchy"); a package in none shows under its segment, with a warning, until it is given one.
$groups = [Collections.Generic.List[object]]::new()
$groupOfSegment = @{}
foreach ($category in $categories) {
    foreach ($entry in @($category.Groups)) {
        $group = [pscustomobject]$entry
        $group | Add-Member -NotePropertyMembers @{ Category = $category.Key; Slug = Get-Anchor $group.Name }
        $key = "$($category.Key)|$($group.Segment)"
        if (-not $group.Segment -or $groupOfSegment.ContainsKey($key)) {
            throw "group '$($group.Name)' needs a Segment of its own: a group is one project and the projects under it"
        }
        $groups.Add($group)
        $groupOfSegment[$key] = $group
    }
}
$ungrouped = @($projects | Where-Object { -not (Get-Group $_.Name) } | ForEach-Object Name)
if ($ungrouped) { Write-Warning "packages in no group of categories.psd1: $($ungrouped -join ', ')" }

# --- the work folder: generated parts gone, the fixed parts copied in
New-Item -ItemType Directory -Force $WorkDir | Out-Null
$generated = @("libraries", "articles", "samples", "api", "_site", "images", "template", "index.md", "toc.yml", "docfx.json", "filterConfig.yml", "robots.txt")
if (-not $SkipMetadata) { $generated += "api-main" }
foreach ($item in $generated) {
    $path = Join-Path $WorkDir $item
    if (Test-Path $path) { Remove-Item $path -Recurse -Force }
}
Copy-Item (Join-Path $PSScriptRoot "template") $WorkDir -Recurse
Copy-Item (Join-Path $PSScriptRoot "toc.yml") $WorkDir
Copy-Item (Join-Path $PSScriptRoot "filterConfig.yml") $WorkDir
Copy-Item (Join-Path $PSScriptRoot "images") $WorkDir -Recurse
Copy-Item (Join-Path $vpnHood "VpnHood.png") (Join-Path $WorkDir "images/logo.png")
Write-Text (Join-Path $WorkDir "robots.txt") "User-agent: *`nAllow: /`nSitemap: $($BaseUrl)sitemap.xml`n"

# the API in one group: a global TargetFramework would reach every referenced project too and break their types
$config = Read-Text (Join-Path $PSScriptRoot "docfx.json") | ConvertFrom-Json -AsHashtable
$config.metadata = @(@{
    src = @($projects | ForEach-Object {
        $projectDir = Split-Path $_.Csproj -Parent
        @{ src = (Split-Path $projectDir -Parent).Replace("\", "/"); files = @("$(Split-Path $projectDir -Leaf)/$(Split-Path $_.Csproj -Leaf)") }
    })
    dest = "api-main"; namespaceLayout = "flattened"; enumSortOrder = "declaringOrder"; filter = "filterConfig.yml"
})
$config.build.sitemap.baseUrl = $BaseUrl
$config.build.globalMetadata._canonicalBase = $BaseUrl
Write-Text (Join-Path $WorkDir "docfx.json") ($config | ConvertTo-Json -Depth 20)

Push-Location $PSScriptRoot
try { dotnet tool restore | Out-Null; if ($LASTEXITCODE) { throw "dotnet tool restore failed" } }
finally { Pop-Location }
if (-not $SkipMetadata) { Invoke-Docfx metadata, (Join-Path $WorkDir "docfx.json") }

# --- the API reference: every page into api/, the namespaces grouped by the category of the assembly that holds them
$apiMain = Join-Path $WorkDir "api-main"
$api = Join-Path $WorkDir "api"
New-Item -ItemType Directory -Force $api | Out-Null
$namespaceCategory = @{}; $namespaceFeature = @{}; $namespacesOf = @{}
# every documented uid, and the short names that name exactly one (a type's own name, Type.Member for a member), so
# a code name in a page can link to its API page; an empty value marks a short name that two uids share
$uids = [Collections.Generic.HashSet[string]]::new()
$shortUid = [Collections.Generic.Dictionary[string, string]]::new()
foreach ($file in Get-ChildItem $apiMain -Filter *.yml) {
    if ($file.Name -eq "toc.yml") { continue }
    $text = Read-Text $file.FullName
    $items = ($text -split "(?m)^references:", 2)[0]
    foreach ($chunk in ($items -split "(?m)^- uid: ") | Select-Object -Skip 1) {
        $uid = ($chunk -split "\s", 2)[0]
        if ($uid -match '[(`{]') { continue }  # a method with parameters, or a generic: no code name matches it
        [void]$uids.Add($uid)
        $kind = [regex]::Match($chunk, "(?m)^  type: (\S+)").Groups[1].Value
        $segments = $uid.Split(".")
        $short = if ($kind -in "Class", "Struct", "Interface", "Enum", "Delegate") { $segments[-1] }
                 elseif ($kind -in "Property", "Field", "Event", "Method" -and $segments.Count -gt 1) { "$($segments[-2]).$($segments[-1])" }
                 else { $null }
        if (-not $short) { continue }
        if (-not $shortUid.ContainsKey($short)) { $shortUid[$short] = $uid }
        elseif ($shortUid[$short] -ne $uid) { $shortUid[$short] = "" }
    }
    $assembly = [regex]::Match($text, "(?m)^  assemblies:\r?\n  - (\S+)")
    $namespace = [regex]::Match($text, "(?m)^  namespace: (\S+)")
    if ($assembly.Success -and $namespace.Success -and $categoryOf.ContainsKey($assembly.Groups[1].Value)) {
        $assemblyName = $assembly.Groups[1].Value; $namespaceName = $namespace.Groups[1].Value
        if (-not $namespaceCategory.ContainsKey($namespaceName)) {
            $namespaceCategory[$namespaceName] = $categoryOf[$assemblyName]
            $namespaceFeature[$namespaceName] = Get-Feature $assemblyName
        }
        if (-not $namespacesOf.ContainsKey($assemblyName)) { $namespacesOf[$assemblyName] = [Collections.Generic.HashSet[string]]::new() }
        [void]$namespacesOf[$assemblyName].Add($namespaceName)
    }
    Copy-Item $file.FullName $api
}

# the generated TOC's top-level blocks, by uid
$blocks = [ordered]@{}; $current = $null
foreach ($line in [IO.File]::ReadAllLines((Join-Path $apiMain "toc.yml"))) {
    if ($line.StartsWith("- uid:")) {
        $current = $line.Split(":", 2)[1].Trim()
        $blocks[$current] = [Collections.Generic.List[string]]::new()
        $blocks[$current].Add($line)
    }
    elseif ($line -match "^[A-Za-z#]") { $current = $null }
    elseif ($null -ne $current) { $blocks[$current].Add($line) }
}
$toc = [Collections.Generic.List[string]]::new()
$toc.Add("### YamlMime:TableOfContent"); $toc.Add("items:")
foreach ($category in $categories) {
    $mine = @($blocks.Keys | Where-Object { $namespaceCategory[$_] -eq $category.Key } | Sort-Object { $_.ToLowerInvariant() })
    if (-not $mine) { continue }
    $toc.Add("- name: $($category.Title)"); $toc.Add("  items:")
    foreach ($group in Group-ByFeature $category.Key ($mine | ForEach-Object { [pscustomobject]@{ Feature = $namespaceFeature[$_]; Item = $_ } })) {
        $toc.Add("  - name: $($group.Name)"); $toc.Add("    items:")
        foreach ($uid in $group.Items) { foreach ($line in $blocks[$uid]) { $toc.Add("    $line") } }
    }
}
$unplaced = @($blocks.Keys | Where-Object { -not $namespaceCategory.ContainsKey($_) })
if ($unplaced) { Write-Warning "namespaces with no category: $($unplaced -join ', ')" }
$toc.Add("memberLayout: SamePage")
Write-Text (Join-Path $api "toc.yml") (($toc -join "`n") + "`n")

# --- the libraries: a page for every package, grouped like the API and named by its package
$dependsOn = @{}; $usedBy = @{}
foreach ($project in $projects) {
    $dependsOn[$project.Name] = @(Get-References $project.Csproj | Where-Object { $categoryOf.ContainsKey($_) -and $_ -ne $project.Name } | Sort-Object -Unique)
}
foreach ($name in $dependsOn.Keys) {
    foreach ($dependency in $dependsOn[$name]) {
        if (-not $usedBy.ContainsKey($dependency)) { $usedBy[$dependency] = [Collections.Generic.List[string]]::new() }
        $usedBy[$dependency].Add($name)
    }
}
$libraryToc = [Collections.Generic.List[string]]::new()
$libraryToc.Add("- name: Overview"); $libraryToc.Add("  href: index.md")
foreach ($category in $categories) {
    $pages = @($projects | Where-Object Category -eq $category.Key)
    if (-not $pages) { continue }
    foreach ($project in $pages) {
        $description = Get-Description $project.Csproj
        $front = if ($description) { ConvertTo-FrontMatter ([ordered]@{ description = $description }) } else { "" }
        $body = if ($project.Readme) { Add-ApiLinks (Read-Text $project.Readme) }
                else { New-PackagePage $project $description $namespacesOf[$project.Name] $dependsOn[$project.Name] $usedBy[$project.Name] }
        Write-Text (Join-Path $WorkDir "libraries/$($category.Key)/$($project.Name).md") ($front + $body)
    }
    $libraryToc.Add("- name: $($category.Title)"); $libraryToc.Add("  items:")
    foreach ($group in Group-ByFeature $category.Key ($pages | ForEach-Object { [pscustomobject]@{ Feature = Get-Feature $_.Name; Item = $_.Name } })) {
        # the group's name opens its page and unfolds its packages
        $libraryToc.Add("  - name: $($group.Name)"); $libraryToc.Add("    href: $($category.Key)/$(Get-Anchor $group.Name).md"); $libraryToc.Add("    items:")
        foreach ($name in $group.Items) { $libraryToc.Add("    - name: $name"); $libraryToc.Add("      href: $($categoryOf[$name])/$name.md") }
    }
}
Write-Text (Join-Path $WorkDir "libraries/toc.yml") (($libraryToc -join "`n") + "`n")

# --- the articles: the allow-list's pages, a link to any other page of the repo sent to its copy on GitHub
$listed = @{}
foreach ($article in $articles) { $listed["docs/$($article.File)"] = $article.File }
$articleToc = [Collections.Generic.List[string]]::new()
foreach ($article in $articles) {
    $dir = "docs/$($article.File)" -replace "/[^/]*$", ""
    $text = [regex]::Replace((Read-Text (Join-Path $vpnHood "docs/$($article.File)")), '\]\(([^)\s#]+)(#[^)\s]*)?\)', {
        param($match)
        $target = $match.Groups[1].Value; $anchor = $match.Groups[2].Value
        if ($target -match "^[a-zA-Z][a-zA-Z0-9+.-]*:") { return $match.Value }  # a URL, mailto: or xref:
        $path = Resolve-RepoPath $dir $target
        if ($listed.ContainsKey($path)) { return "]($($listed[$path])$anchor)" }
        "]($githubBlob$path$anchor)"
    })
    # a sample's folder on GitHub is its page here, where it has one (Samples and templates, below)
    $text = [regex]::Replace($text, '\]\(https://github\.com/vpnhood/VpnHood\.App\.Samples/tree/main/([A-Za-z0-9_.-]+)/?\)', {
        param($match)
        $name = $match.Groups[1].Value
        if (Test-Path (Join-Path $SamplesRoot "$name/README.md")) { return "](../samples/$name.md)" }
        $match.Value
    })
    $text = Add-ApiLinks $text
    $front = [ordered]@{ description = $article.Description }
    if ($article.Hero) {
        # the banner holds the page's title, so the page goes without its own
        $heading = [regex]::new('(?m)^# ([^\r\n]*)\r?\n')
        $title = $heading.Match($text)
        if (-not $title.Success) { throw "docs/$($article.File) has no title for its banner" }
        $text = $text.Remove($title.Index, $title.Length)
        $front["title"] = $title.Groups[1].Value
        Add-Hero $front $title.Groups[1].Value $article.Hero
    }
    # the page's steps: its first numbered list, each item with its picture and its bold lead as the step's title
    # (owner, 2026-11-13: "can you work on presentation of the items 1,2,3 here")
    if ($article.Steps) {
        $lines = [Collections.Generic.List[string]]::new([string[]]($text -split "\r?\n"))
        $start = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^1\. ') { $start = $i; break } }
        if ($start -lt 0) { throw "docs/$($article.File) has no numbered list for its steps" }
        $count = 0; $end = $lines.Count
        for ($i = $start; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\d+\. ') {
                if ($count -ge $article.Steps.Count) { throw "docs/$($article.File) has more steps than pictures" }
                $step = $article.Steps[$count++]
                $rest = $lines[$i].Substring($Matches[0].Length) -replace '^\*\*(.+?)\.\*\*', '**$1**'
                $lines[$i] = $Matches[0] + "<img class=""vh-step-art"" src=""../$($step.Art)"" alt=""$(ConvertTo-Html $step.Alt)""> " + $rest
            }
            elseif ($lines[$i] -and $lines[$i] -notmatch '^\s') { $end = $i; break }
        }
        if ($count -ne $article.Steps.Count) { throw "docs/$($article.File) has $count steps for $($article.Steps.Count) pictures" }
        $lines.InsertRange($end, [string[]]@("", "</div>", ""))
        $lines.InsertRange($start, [string[]]@("<div class=""vh-steps"">", ""))
        $text = $lines -join "`n"
    }
    Write-Text (Join-Path $WorkDir "articles/$($article.File)") ((ConvertTo-FrontMatter $front) + $text)
    $articleToc.Add("- name: $($article.Title)"); $articleToc.Add("  href: $($article.File)")
}
Write-Text (Join-Path $WorkDir "articles/toc.yml") (($articleToc -join "`n") + "`n")

# --- Samples and templates (owner, 2026-11-15: "a page for our sample and describe them what they do. So they can go
# and check the samples. Later, we need to add templates too"): each is a repository of its own, and its words are its
# README's, so nothing is written twice. The template, a whole app, comes first; the samples follow, each one part of
# VpnHood at work. The SPA's sample is not one of them (owner: "I don't think we should refer to SPA because it is
# complicated", and "the template sample would work much better than SPA").
$github = "https://github.com/vpnhood/"

# a README's first paragraph, its title and notes passed over
function Get-Lead([string]$readme) {
    foreach ($block in ((Read-Text $readme) -split '\r?\n\s*\r?\n')) {
        $block = $block.Trim()
        if ($block -and $block -notmatch '^(#|>|\||<|!\[)') { return ($block -split '\s*\r?\n\s*') -join " " }
    }
    throw "$readme has no paragraph to describe its repository"
}

$samplesTree = "$($github)VpnHood.App.Samples/tree/main/"
$samplesReadme = Read-Text (Join-Path $SamplesRoot "README.md")
$samplesTitle = [regex]::Match($samplesReadme, '(?m)^# [^\r\n]*\r?\n')
if (-not $samplesTitle.Success) { throw "VpnHood.App.Samples' README has no title" }

# A sample with a README in its folder gets a page of its own, made from it (owner, 2026-11-15: "a readme in each folder
# of the sample", with its screenshot): its pictures go beside the page, and its other links, to its files and the other
# samples' folders, to GitHub. Its folder on GitHub comes under its title.
$sampleNames = [Collections.Generic.List[string]]::new()
foreach ($match in [regex]::Matches($samplesReadme, '\]\(([A-Za-z0-9_.-]+)/?\)')) {
    $name = $match.Groups[1].Value
    if ((Test-Path (Join-Path $SamplesRoot "$name/README.md")) -and -not $sampleNames.Contains($name)) { $sampleNames.Add($name) }
}
$sampleToc = [Collections.Generic.List[string]]::new([string[]]@("- name: Samples and templates", "  href: index.md"))
foreach ($name in $sampleNames) {
    $text = Read-Text (Join-Path $SamplesRoot "$name/README.md")
    $text = [regex]::Replace($text, '\]\(([^)\s#]+)(#[^)\s]*)?\)', {
        param($match)
        $target = $match.Groups[1].Value; $anchor = $match.Groups[2].Value
        if ($target -match "^[a-zA-Z][a-zA-Z0-9+.-]*:") { return $match.Value }  # a URL
        $file = Join-Path $SamplesRoot "$name/$target"
        if ($target -match '\.(png|jpe?g|webp|gif|svg)$' -and (Test-Path $file)) {
            $copy = Join-Path $WorkDir "samples/$name/$target"
            New-Item -ItemType Directory -Force (Split-Path $copy -Parent) | Out-Null
            Copy-Item $file $copy
            return "]($name/$target)"
        }
        $path = (Resolve-RepoPath $name $target).TrimEnd("/")
        if ($sampleNames.Contains($path)) { return "]($path.md$anchor)" }
        "]($samplesTree$path$anchor)"
    })
    $text = $text -replace '\]\(https://developer\.vpnhood\.com/([^)\s#]+?)\.html', '](../$1.md'  # this site's own pages
    $title = [regex]::Match($text, '(?m)^# [^\r\n]*\r?\n')
    if (-not $title.Success) { throw "$name's README has no title" }
    $text = $text.Insert($title.Index + $title.Length, "`n[$name on GitHub]($samplesTree$name)`n")
    Write-Text (Join-Path $WorkDir "samples/$name.md") ((ConvertTo-FrontMatter ([ordered]@{ description = (Get-Lead (Join-Path $SamplesRoot "$name/README.md")) -replace '`', '' })) +
        (Add-ApiLinks $text))
    $sampleToc.Add("- name: $name"); $sampleToc.Add("  href: $name.md")
}

# the samples' README under the page's Samples heading, its own headings a level down: a sample with a page links to
# it, any other folder to GitHub, and this site's own pages within the site; the pictures it shows go beside the page
$samples = $samplesReadme.Substring($samplesTitle.Index + $samplesTitle.Length).Trim()
$samples = [regex]::Replace($samples, 'src="([^":]+\.(?:png|jpe?g|webp|gif|svg))"', {
    param($match)
    $file = Join-Path $SamplesRoot $match.Groups[1].Value
    if (-not (Test-Path $file)) { throw "VpnHood.App.Samples' README shows $($match.Groups[1].Value), which it does not have" }
    $copy = Join-Path $WorkDir "samples/$($match.Groups[1].Value)"
    New-Item -ItemType Directory -Force (Split-Path $copy -Parent) | Out-Null
    Copy-Item $file $copy -Force
    $match.Value
})
$samples = [regex]::Replace($samples, '\]\(([^)\s#:]+)\)', {
    param($match)
    $target = $match.Groups[1].Value.TrimStart('./').TrimEnd('/')
    if ($sampleNames.Contains($target)) { return "]($target.md)" }
    "]($samplesTree$target)"
})
$samples = $samples -replace '\]\(https://developer\.vpnhood\.com/([^)\s#]+?)\.html', '](../$1.md'
$samples = [regex]::Replace($samples, '(?m)^(#{2,5}) ', '#$1 ')
$page = @"
# Samples and templates

Start from a template to make a whole app of your own, or read a sample to see one part of VpnHood at work. Each is a
repository on GitHub, built on VpnHood's NuGet packages.

## Templates

| Template | What it is |
| --- | --- |
| [VpnHood.App.Template]($($github)VpnHood.App.Template) | $(Get-Lead (Join-Path $TemplateRoot "README.md")) [Build your VPN app](../articles/build-your-app.md) makes it yours. |

## Samples

$samples
"@
Write-Text (Join-Path $WorkDir "samples/index.md") ((ConvertTo-FrontMatter ([ordered]@{
    description = "VpnHood's app template and its samples: a whole VPN app to make your own, and small apps that each show one part of VpnHood at work." })) +
    (Add-ApiLinks $page))
Write-Text (Join-Path $WorkDir "samples/toc.yml") (($sampleToc -join "`n") + "`n")

# --- a page for every group: what it is for, when to use it, which package to take, and its packages (owner, 2026-11-13:
# "describe in their landing page that whats the use of this, when to use it")
function Get-PackageRow($project) {
    $first = ((Get-Description $project.Csproj) -split "(?<=[.!?])\s", 2)[0] -replace "\|", "\|"
    $links = @("[$(if ($project.Readme) { 'Guide' } else { 'Overview' })]($($project.Name).md)")
    $namespaces = @($namespacesOf[$project.Name] | Sort-Object { $_.Length })
    if ($namespaces) { $links += "[API](xref:$(if ($namespaces -contains $project.Name) { $project.Name } else { $namespaces[0] }))" }
    "| $($project.Name) | $first | $($links -join '&nbsp;·&nbsp;') |"
}

$groupCards = @{}
foreach ($category in $categories) {
    $pages = @($projects | Where-Object Category -eq $category.Key)
    $cards = [Collections.Generic.List[string]]::new()
    foreach ($bundle in Group-ByFeature $category.Key ($pages | ForEach-Object { [pscustomobject]@{ Feature = Get-Feature $_.Name; Item = $_ } })) {
        $group = $groups | Where-Object { $_.Category -eq $category.Key -and $_.Name -eq $bundle.Name } | Select-Object -First 1
        $slug = Get-Anchor $bundle.Name
        $members = @($bundle.Items)
        $page = [Collections.Generic.List[string]]::new()
        # its browser title names the category too: three groups are named Abstraction
        $page.Add((ConvertTo-FrontMatter ([ordered]@{
            title = "$($bundle.Name) - $($category.Title)"
            description = $(if ($group.Text) { $group.Text } else { "The $($bundle.Name) packages of VpnHood." }) })).TrimEnd())
        $page.Add(""); $page.Add("# $($bundle.Name)"); $page.Add("")
        if ($group.Intro) {
            $art = if ($group.Art) { "<img class=""vh-group-image"" src=""../../$($group.Art)"" alt="""">" } else { "" }
            $page.Add("<div class=""vh-category-hero vh-group-hero""><div class=""vh-category-text""><p class=""vh-category-intro"">$(ConvertTo-Html $group.Intro)</p></div>$art</div>")
        }
        # a section with a diagram, as Proxy management's of what goes through a proxy (owner, 2026-11-13: "show an image
        # or diagram with that, which tunnels goes through proxy")
        if ($group.Diagram) {
            $page.Add(""); $page.Add("## $($group.Diagram.Title)"); $page.Add("")
            $page.Add("<p class=""vh-group-diagram""><img src=""../../$($group.Diagram.Image)"" alt=""$(ConvertTo-Html $group.Diagram.ImageAlt)""></p>")
            foreach ($line in $group.Diagram.Text) { $page.Add(""); $page.Add($line) }
        }
        if ($group.Use) {
            $page.Add(""); $page.Add("## When to use it"); $page.Add("")
            foreach ($line in $group.Use) { $page.Add("- $line") }
        }
        if ($group.Pick) {
            $page.Add(""); $page.Add("## Which package to take"); $page.Add("")
            foreach ($line in $group.Pick) { $page.Add("- $line") }
        }
        $page.Add(""); $page.Add($(if ($members.Count -eq 1) { "## Its package" } else { "## Its packages" })); $page.Add("")
        $page.Add("| Package | What it does | |"); $page.Add("|---|---|---|")
        foreach ($project in $members) { $page.Add((Get-PackageRow $project)) }
        Write-Text (Join-Path $WorkDir "libraries/$($category.Key)/$slug.md") (Add-ApiLinks (($page -join "`n") + "`n"))

        # its card on the Libraries page; an abstraction's has a dashed border, as its drawing has
        $art = if ($group.Art) { "<img class=""vh-group-art"" src=""../$($group.Art)"" alt="""">" } else { "" }
        $count = if ($members.Count -eq 1) { "1 package" } else { "$($members.Count) packages" }
        $text = if ($group.Text) { "<span class=""vh-part-text"">$(ConvertTo-Html $group.Text)</span>" } else { "" }
        $cards.Add("  <div class=""col""><a class=""vh-part vh-group$(if ($group.Abstraction) { ' vh-group-abstraction' })"" href=""$($category.Key)/$slug.md"">$art" +
            "<span class=""vh-part-title"">$(ConvertTo-Html $bundle.Name)</span>$text<span class=""vh-group-count"">$count</span></a></div>")
    }
    $groupCards[$category.Key] = $cards
}

# --- Libraries' front page: a map, each category with its groups as cards; the packages are on the groups' pages, as all
# of them on one page made a long list (owner, 2026-11-13: "removing the list here and keep title, its a long scray list")
$catalog = [Collections.Generic.List[string]]::new()
$catalog.Add((ConvertTo-FrontMatter ([ordered]@{
    description = "VpnHood's packages by what they do: networking, the VPN engine, the app's logic and its UI. Each group says what it is for, when to use it and which package to take." })).TrimEnd())
$catalog.Add(""); $catalog.Add("# Libraries"); $catalog.Add("")
$catalog.Add("Every part of VpnHood is a set of packages on [NuGet](https://www.nuget.org/profiles/VpnHood). Pick a group: its page " +
    "says what it is for, when to use it, and which package to take.")
foreach ($category in $categories) {
    if (-not $groupCards[$category.Key].Count) { continue }
    $catalog.Add(""); $catalog.Add("## $($category.Title)"); $catalog.Add(""); $catalog.Add($category.Intro); $catalog.Add("")
    $catalog.Add("<div class=""row row-cols-1 row-cols-md-2 g-3 vh-groups"">")
    foreach ($card in $groupCards[$category.Key]) { $catalog.Add($card) }
    $catalog.Add("</div>")
}
Write-Text (Join-Path $WorkDir "libraries/index.md") (($catalog -join "`n") + "`n")

# --- the API reference's front page: each big category with what it is for and its picture if it has one, then
# real-world scenarios that lead to their packages. The picture sits beside the text at a fixed width: at the column's
# full width it was too big, at a third of it too small to read. Its HTML blocks have no blank line inside, which would
# end them.
$apiFront = [Collections.Generic.List[string]]::new()
$apiFront.Add((ConvertTo-FrontMatter ([ordered]@{
    description = "The API reference of VpnHood's .NET packages: networking, the VPN engine, the app's logic and its UI, with what you can build with each." })).TrimEnd())
$apiFront.Add(""); $apiFront.Add("# API reference"); $apiFront.Add("")
$apiFront.Add("Every public type and member of the VpnHood packages, from the doc comments that IntelliSense shows too. Search for " +
    "a type at the top of the page, or browse the menu. Below is what each part of VpnHood is for.")
foreach ($category in $categories) {
    $anchor = Get-Anchor $category.Title
    $html = [Collections.Generic.List[string]]::new()
    $html.Add("<section class=""vh-category"" id=""$anchor"">")
    $html.Add("  <div class=""vh-category-hero"">")
    $html.Add("    <div class=""vh-category-text""><h2>$(ConvertTo-Html $category.Title)</h2><p class=""vh-category-intro"">$(ConvertTo-Html $category.Intro)</p>")
    $html.Add("    <p><a href=""../libraries/index.md#$anchor"">Its packages</a></p></div>")
    if ($category.Image) {
        $html.Add("    <img class=""vh-category-image"" src=""../$($category.Image)"" alt=""$(ConvertTo-Html $category.ImageAlt)"">")
    }
    $html.Add("  </div>")
    $html.Add("  <div class=""row row-cols-1 row-cols-md-2 g-3 vh-scenarios"">")
    foreach ($scenario in $category.Scenarios) {
        $packageLinks = foreach ($name in $scenario.Packages) {
            if (-not $categoryOf.ContainsKey($name)) { throw "scenario '$($scenario.Title)' names $name, which is not on the site" }
            "<a href=""../libraries/$($categoryOf[$name])/$name.md"">$($name -replace '^VpnHood\.', '')</a>"
        }
        $html.Add("    <div class=""col""><div class=""vh-scenario""><p class=""vh-scenario-title"">$([Net.WebUtility]::HtmlEncode($scenario.Title))</p>" +
            "<p>$([Net.WebUtility]::HtmlEncode($scenario.Text))</p><p class=""vh-scenario-packages"">$($packageLinks -join ' · ')</p></div></div>")
    }
    $html.Add("  </div>")
    $html.Add("</section>")
    $apiFront.Add(""); foreach ($line in $html) { $apiFront.Add($line) }
}
Write-Text (Join-Path $api "index.md") (($apiFront -join "`n") + "`n")

# --- the home page: where to start, not a list. The code is Net.VpnAdapters.WinTun's README example, which the tests
# compile, without the comments the README keeps, so it fits its card; a blank line would end the HTML block it sits
# in, so it has none.
$example = [regex]::Match((Read-Text (Join-Path $src "Net/VpnHood.Net.VpnAdapters.WinTun/README.md")), '(?s)```csharp Snippet:VpnAdapterWinTun\r?\n(.*?)\r?\n```')
if (-not $example.Success) { throw "VpnHood.Net.VpnAdapters.WinTun's README has no VpnAdapterWinTun example" }
$code = [Net.WebUtility]::HtmlEncode((($example.Groups[1].Value -split "\r?\n") |
    Where-Object { $_.Trim() -and $_ -notmatch "^\s*//" } | ForEach-Object { $_ -replace "\s+//\s.*$", "" }) -join "`n")
# the four parts of VpnHood, each a small card - its small drawing, its name and the first sentence of what it is for -
# that leads to its section of the API reference's front page, where its picture is: four big pictures made the home
# page too heavy. The drawing is decorative, as the card names its part.
$parts = foreach ($category in $categories) {
    $first = ($category.Intro -split "(?<=[.!?])\s", 2)[0]
    "  <div class=""col""><a class=""vh-part"" href=""api/index.md#$(Get-Anchor $category.Title)"">" +
        "<img class=""vh-part-art"" src=""$($category.Art)"" alt="""">" +
        "<span class=""vh-part-title"">$(ConvertTo-Html $category.Title)</span><span class=""vh-part-text"">$(ConvertTo-Html $first)</span></a></div>"
}
$homeFront = [ordered]@{ _layout = "landing"; title = "VpnHood for developers"
    description = "Build your own VPN app for Android, iOS, Windows and Linux, or use VpnHood's open-source .NET packages in yours: guides, a page for every package, and the API reference." }
# the forge's left side, four tenths of it, is an empty wall kept for the copy, so the forge takes the banner's whole
# width, its top kept, and no more: zoomed closer, the 4:1 banner only crops it differently (owner, 2026-11-14: "don't
# zoom it"); on a phone the scene's right side, where the work is
Add-Hero $homeFront "VpnHood for developers" @{ Image = "images/hero-forge.webp"; Small = "images/hero-forge-small.webp"
        Width = 2160; Height = 720; ArtWidth = "100cqw"; Position = "center 26%"; Clear = "0.42"; Ratio = "16 / 9"
        Focus = "right center"
        Alt = "A hooded woman holds hot iron with tongs while a craftsman forges it beside a furnace built into the stone wall." } `
    "Build your own VPN app from our template, or use VpnHood's parts in any .NET application. It is open source, and every part is a NuGet package." `
    ('<a class="btn btn-light btn-lg" href="articles/build-your-app.html">Build your VPN app</a> ' +
     '<a class="btn btn-outline-light btn-lg" href="libraries/index.html">Browse the libraries</a>')
Write-Text (Join-Path $WorkDir "index.md") ((ConvertTo-FrontMatter $homeFront) + @"
<div class="row row-cols-1 row-cols-md-3 g-4 vh-cards">
  <div class="col"><a class="card h-100" href="articles/build-your-app.md">
    <div class="vh-card-visual"><img src="images/card-your-app.svg" alt="An app made from the template under a brand of its own: its connect screen, connected, and its list of locations"></div>
    <div class="card-body"><h2 class="h5 card-title">Build your VPN app</h2>
    <p class="card-text">Start from the template: a repository that holds only your app, for Android, iOS, Windows and Linux. A Debug build connects to our sample server.</p></div>
  </a></div>
  <div class="col"><a class="card h-100" href="articles/client-architecture.md">
    <div class="vh-card-visual"><img src="images/card-layers.svg" alt="The layers of a VpnHood app, top to bottom: the head you publish, its screens, its logic, the VPN engine and the networking beneath, with the app API and the VPN service contract between them"></div>
    <div class="card-body"><h2 class="h5 card-title">VpnHood Client Architecture</h2>
    <p class="card-text">A head over three layers, the UI, the app's logic and the VPN engine, which meet at two contracts. Replace any layer on its own.</p></div>
  </a></div>
  <div class="col"><a class="card h-100" href="libraries/index.md#networking">
    <div class="vh-card-visual vh-card-code"><pre><code class="lang-csharp">$code</code></pre></div>
    <div class="card-body"><h2 class="h5 card-title">Use the networking libraries</h2>
    <p class="card-text">Open a TUN adapter and handle its packets in a few lines; the Linux, Android and iOS adapters take the same calls. IP packets, a user-space TCP stack, QUIC and proxies too, for any .NET application.</p></div>
  </a></div>
</div>

## Use any part of VpnHood

Four layers of NuGet packages, from networking libraries that need no VPN to the screens of a finished app. Each part's
page says what you can build with it.

<div class="row row-cols-1 row-cols-md-2 row-cols-lg-4 g-3 vh-parts">
$($parts -join "`n")
</div>

<p class="vh-explore">Looking for a type? Search at the top of the page, or open the <a href="api/index.md">API reference</a>. The source is on <a href="https://github.com/vpnhood/VpnHood">GitHub</a>, and every package is on <a href="https://www.nuget.org/profiles/VpnHood">NuGet</a>.</p>
"@)

Invoke-Docfx build, (Join-Path $WorkDir "docfx.json")

# a folder's page is its address: the canonical link and the sitemap name the folder, not its index.html
$site = Join-Path $WorkDir "_site"
foreach ($page in Get-ChildItem $site -Filter index.html -Recurse) {
    $text = Read-Text $page.FullName
    $fixed = $text -replace '(<link rel="canonical" href="[^"]*/)index\.html"', '$1"'
    if ($fixed -ne $text) { Write-Text $page.FullName $fixed }
}
$sitemap = Join-Path $site "sitemap.xml"
if (Test-Path $sitemap) { Write-Text $sitemap ((Read-Text $sitemap) -replace "/index\.html</loc>", "/</loc>") }
Write-Host "Built: $site"
