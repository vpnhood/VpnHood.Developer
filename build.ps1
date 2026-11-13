<#
.SYNOPSIS
Builds developer.vpnhood.com into a folder outside the repos.

.DESCRIPTION
The site's text is VpnHood's own, read from a clone of vpnhood/VpnHood next to this repo; this repo adds the look, the
pictures and the categories. The site has three parts:
- Start here: the hand-written pages on the allow-list below, copied from VpnHood's docs/. Never a glob: the rest of
  docs/ is maintainer notes, not product documentation. A link to a page left out goes to its copy on GitHub.
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
    [string]$BaseUrl = "https://developer.vpnhood.com/",
    # keep the last run's API metadata, when only the pages changed
    [switch]$SkipMetadata
)

$ErrorActionPreference = "Stop"
$vpnHood = (Resolve-Path $VpnHoodRoot).Path
$src = Join-Path $vpnHood "src"
$ProxiesRoot = (Resolve-Path $ProxiesRoot).Path
$githubBlob = "https://github.com/vpnhood/VpnHood/blob/develop/"

# the four big categories, with their pictures and real-world scenarios
$categories = @((Import-PowerShellDataFile (Join-Path $PSScriptRoot "categories.psd1")).Categories | ForEach-Object { [pscustomobject]$_ })

# A package's feature is the third segment of its name (VpnHood.Net.<Feature>...). This names the known ones, merges
# neighbours and sets their order; an unknown one shows as itself, after these.
$features = [ordered]@{
    Proxies = "Proxies"; Packets = "Packets"; PacketTransports = "Packets"; VpnAdapters = "VPN adapters"
    TcpStack = "TCP stack"; Quic = "QUIC"; IpLocations = "IP locations"; Api = "API"
}
$featureOrder = @($features.Values | Select-Object -Unique)

# kept off the site (owner, 2026-11-08); it keeps its doc comments and its NuGet package
$excluded = @("VpnHood.Net.Http3")

# the hand-written pages, in reading order: files of docs/, never a glob
$articles = @(
    [pscustomobject]@{ File = "build-your-app.md"; Title = "Build your VPN app"
        Description = "Build your own VPN app for Android, iOS, Windows and Linux from VpnHood.App.Template, on VpnHood's NuGet packages." }
    [pscustomobject]@{ File = "client-architecture.md"; Title = "How a VpnHood app is built"
        Description = "A VpnHood app is a head over three layers - the UI, the app's logic and the VPN engine - which meet at two contracts; which part to use for what you build." }
)

function Read-Text([string]$path) { [IO.File]::ReadAllText($path).TrimStart([char]0xFEFF) }

function Write-Text([string]$path, [string]$text) {
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
}

function Get-Feature([string]$name) {
    $segment = $name.Split(".")[2]
    if ($features.Contains($segment)) { $features[$segment] } else { $segment }
}

# [(Name, Items)] from (Feature, Item) pairs: the known features first, in their order, then the rest by name
function Group-ByFeature($pairs) {
    @($pairs) | Group-Object Feature |
        Sort-Object @{ Expression = { $i = $featureOrder.IndexOf($_.Name); if ($i -lt 0) { $featureOrder.Count } else { $i } } }, Name |
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

# --- the work folder: generated parts gone, the fixed parts copied in
New-Item -ItemType Directory -Force $WorkDir | Out-Null
$generated = @("libraries", "articles", "api", "_site", "images", "template", "index.md", "toc.yml", "docfx.json", "filterConfig.yml", "robots.txt")
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
    foreach ($group in Group-ByFeature ($mine | ForEach-Object { [pscustomobject]@{ Feature = $namespaceFeature[$_]; Item = $_ } })) {
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
$libraryToc.Add("- name: All packages"); $libraryToc.Add("  href: index.md")
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
    foreach ($group in Group-ByFeature ($pages | ForEach-Object { [pscustomobject]@{ Feature = Get-Feature $_.Name; Item = $_.Name } })) {
        $libraryToc.Add("  - name: $($group.Name)"); $libraryToc.Add("    items:")
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
    $text = Add-ApiLinks $text
    Write-Text (Join-Path $WorkDir "articles/$($article.File)") ((ConvertTo-FrontMatter ([ordered]@{ description = $article.Description })) + $text)
    $articleToc.Add("- name: $($article.Title)"); $articleToc.Add("  href: $($article.File)")
}
Write-Text (Join-Path $WorkDir "articles/toc.yml") (($articleToc -join "`n") + "`n")

# --- Libraries' front page: every package by category and feature, with what it does
$catalog = [Collections.Generic.List[string]]::new()
$catalog.Add((ConvertTo-FrontMatter ([ordered]@{
    description = "Every VpnHood package by what it does: networking, the VPN engine, the app's logic and its UI, each on NuGet." })).TrimEnd())
$catalog.Add(""); $catalog.Add("# Libraries"); $catalog.Add("")
$catalog.Add("Every VpnHood package, by what it does. A package's page says what it is for and how to add it, and leads to its " +
    "API. All of them are on [NuGet](https://www.nuget.org/profiles/VpnHood).")
foreach ($category in $categories) {
    $rows = foreach ($project in @($projects | Where-Object Category -eq $category.Key)) {
        $first = ((Get-Description $project.Csproj) -split "(?<=[.!?])\s", 2)[0] -replace "\|", "\|"
        $links = @("[$(if ($project.Readme) { 'Guide' } else { 'Overview' })]($($category.Key)/$($project.Name).md)")
        $namespaces = @($namespacesOf[$project.Name] | Sort-Object { $_.Length })
        if ($namespaces) { $links += "[API](xref:$(if ($namespaces -contains $project.Name) { $project.Name } else { $namespaces[0] }))" }
        [pscustomobject]@{ Feature = Get-Feature $project.Name; Item = "| $($project.Name) | $first | $($links -join ' · ') |" }
    }
    if (-not $rows) { continue }
    $catalog.Add(""); $catalog.Add("## $($category.Title)"); $catalog.Add(""); $catalog.Add($category.Intro)
    foreach ($group in Group-ByFeature $rows) {
        $catalog.Add(""); $catalog.Add("### $($group.Name)"); $catalog.Add("")
        $catalog.Add("| Package | What it does | |"); $catalog.Add("|---|---|---|")
        foreach ($row in $group.Items) { $catalog.Add($row) }
    }
}
Write-Text (Join-Path $WorkDir "libraries/index.md") (($catalog -join "`n") + "`n")

# --- the API reference's front page: each big category with its picture if it has one, what it is for, and
# real-world scenarios that lead to their packages. Its HTML blocks have no blank line inside, which would end them.
$apiFront = [Collections.Generic.List[string]]::new()
$apiFront.Add((ConvertTo-FrontMatter ([ordered]@{
    description = "The API reference of VpnHood's .NET packages: networking, the VPN engine, the app's logic and its UI, with what you can build with each." })).TrimEnd())
$apiFront.Add(""); $apiFront.Add("# API reference"); $apiFront.Add("")
$apiFront.Add("Every public type and member of the VpnHood packages, from the doc comments that IntelliSense shows too. Search for " +
    "a type at the top of the page, or browse the menu. Below is what each part of VpnHood is for.")
$index = 0
foreach ($category in $categories) {
    $anchor = ($category.Title.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
    $imageOrder = if ($index++ % 2) { " order-md-2" } else { "" }
    $html = [Collections.Generic.List[string]]::new()
    $html.Add("<section class=""vh-category"" id=""$anchor"">")
    $html.Add("  <div class=""vh-category-hero row align-items-center g-4"">")
    if ($category.Image) {
        $html.Add("    <div class=""col-md-4$imageOrder""><img class=""vh-category-image"" src=""../$($category.Image)"" alt=""$([Net.WebUtility]::HtmlEncode($category.Title))""></div>")
    }
    $html.Add("    <div class=""$(if ($category.Image) { 'col-md-8' } else { 'col' })""><h2>$([Net.WebUtility]::HtmlEncode($category.Title))</h2><p class=""lead"">$([Net.WebUtility]::HtmlEncode($category.Intro))</p>")
    $html.Add("    <p><a href=""../libraries/index.md#$anchor"">Its packages</a></p></div>")
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
$homeFront = ConvertTo-FrontMatter ([ordered]@{ _layout = "landing"; title = "VpnHood for developers"
    description = "Build your own VPN app for Android, iOS, Windows and Linux, or use VpnHood's open-source .NET packages in yours: guides, a page for every package, and the API reference." })
Write-Text (Join-Path $WorkDir "index.md") ($homeFront + @"
<div class="vh-hero">
  <h1>Build your own VPN app</h1>
  <p>Or use VpnHood's parts in any .NET application. It is open source, and every part is a NuGet package.</p>
  <p class="vh-hero-actions"><a class="btn btn-light btn-lg" href="articles/build-your-app.md">Build your VPN app</a> <a class="btn btn-outline-light btn-lg" href="libraries/index.md">Browse the libraries</a></p>
</div>

<div class="row row-cols-1 row-cols-md-3 g-4 vh-cards">
  <div class="col"><a class="card h-100" href="articles/build-your-app.md">
    <div class="vh-card-visual"><img src="images/app-phone.webp" alt="VpnHood! CONNECT on two phones: connected, and its list of servers"></div>
    <div class="card-body"><h2 class="h5 card-title">Build your VPN app</h2>
    <p class="card-text">Start from the template: a repository that holds only your app, for Android, iOS, Windows and Linux. A Debug build connects to our sample server.</p></div>
  </a></div>
  <div class="col"><a class="card h-100" href="articles/client-architecture.md">
    <div class="vh-card-visual"><img src="images/layers.svg" alt="The layers of a VpnHood app: the head, the UI, the app's logic, the VPN engine and the networking libraries"></div>
    <div class="card-body"><h2 class="h5 card-title">How a VpnHood app is built</h2>
    <p class="card-text">A head over three layers, the UI, the app's logic and the VPN engine, which meet at two contracts. Replace any layer on its own.</p></div>
  </a></div>
  <div class="col"><a class="card h-100" href="libraries/index.md#networking">
    <div class="vh-card-visual vh-card-code"><pre><code class="lang-csharp">$code</code></pre></div>
    <div class="card-body"><h2 class="h5 card-title">Use the networking libraries</h2>
    <p class="card-text">Open a TUN adapter and handle its packets in a few lines; the Linux, Android and iOS adapters take the same calls. IP packets, a user-space TCP stack, QUIC and proxies too, for any .NET application.</p></div>
  </a></div>
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
