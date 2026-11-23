<#
.SYNOPSIS
Refreshes the site's copies of the VpnHood! MANAGER API: its description and the guide's requests with their answers.

.DESCRIPTION
The MANAGER's repository is private, so the site keeps copies of what it shows: manager-api/examples.json, the requests
the guide shows with the answers they got, and manager-api/openapi.json, the API's description, which the build uses
only when it is newer than the live MANAGER's. Both come from the MANAGER's tests, which run the MANAGER in-process
(Docker runs their databases): ApiDescriptionTest fails when a name has no description, and ApiGuideTest makes the
guide's requests as a bot. Nothing is copied unless both pass. Run it after a change to ApiGuideTest, which reminds
you when it fails, or to show an API change on the site before its release.

.EXAMPLE
pwsh ./tools/update-manager-api.ps1
#>
param(
    # a clone of vpnhood/VpnHood.Manager
    [string]$ManagerRoot = (Join-Path $PSScriptRoot "../../VpnHood.Manager")
)

$ErrorActionPreference = "Stop"
$work = Join-Path ([IO.Path]::GetTempPath()) "vh/manager-api-update"
New-Item -ItemType Directory -Force $work | Out-Null
$description = Join-Path $work "openapi.json"
$examples = Join-Path $work "examples.json"
Remove-Item $description, $examples -ErrorAction SilentlyContinue

$env:VH_MANAGER_API_DESCRIPTION = $description
$env:VH_MANAGER_API_EXAMPLES = $examples
try {
    dotnet test (Join-Path $ManagerRoot "tests/VpnHood.Manager.Test/VpnHood.Manager.Test.csproj") `
        --filter "FullyQualifiedName~ApiDescriptionTest|FullyQualifiedName~ApiGuideTest"
    if ($LASTEXITCODE) { throw "The MANAGER's API tests failed, so nothing is copied." }
}
finally {
    Remove-Item Env:VH_MANAGER_API_DESCRIPTION, Env:VH_MANAGER_API_EXAMPLES -ErrorAction SilentlyContinue
}

# the tests' MANAGER answered on localhost; the site's copy names the public one
$document = Get-Content $description -Raw | ConvertFrom-Json -AsHashtable
$document["servers"] = @([ordered]@{ url = "https://api.vpnhood.com" })
$target = Join-Path $PSScriptRoot "../manager-api"
[IO.File]::WriteAllText((Join-Path $target "openapi.json"), ($document | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
Copy-Item $examples (Join-Path $target "examples.json") -Force
Write-Host "Updated manager-api/openapi.json and manager-api/examples.json"
