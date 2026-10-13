param([string]$LuauDirectory = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    $interpreter = if ($LuauDirectory) { Join-Path $LuauDirectory 'luau.exe' } else { 'luau' }
    $compiler = if ($LuauDirectory) { Join-Path $LuauDirectory 'luau-compile.exe' } else { 'luau-compile' }
    $sourceFiles = Get-ChildItem -LiteralPath src,tests -Filter '*.luau' -Recurse
    foreach ($file in $sourceFiles) {
        & $compiler --null $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $($file.FullName)" }
    }
    & $interpreter tests/Rocket.spec.luau
    if ($LASTEXITCODE -ne 0) { throw 'Rocket checks failed' }
    New-Item -ItemType Directory -Path build -Force | Out-Null
    $profileSource = Get-Content -LiteralPath src/ServerScriptService/Services/ProfileService.luau -Raw
    $profileTests = Get-Content -LiteralPath tests/Profiles.spec.luau -Raw
    $harness = "local function loadProfiles(game, task)`nlocal warn = print`n" + $profileSource + "`nend`n" + $profileTests
    Set-Content -LiteralPath build/Profiles.test.luau -Value $harness -Encoding utf8
    & $interpreter build/Profiles.test.luau
    if ($LASTEXITCODE -ne 0) { throw 'Profile checks failed' }
    Write-Output 'PASS: all Luau sources compile and focused game/profile checks pass'
} finally { Pop-Location }
