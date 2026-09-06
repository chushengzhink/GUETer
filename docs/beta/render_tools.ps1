$ErrorActionPreference = 'Stop'
$betaRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$betaBeforePath = Join-Path $betaRoot 'lib/pages/beta_tools_before.dart'
$betaTestPath = Join-Path $betaRoot '_tmp/beta_render_test.dart'
if (Test-Path -LiteralPath $betaBeforePath) {
    throw 'Temporary baseline page already exists; refusing to overwrite it.'
}
Push-Location $betaRoot
try {
    # The original tools page had no uncommitted changes at the beta baseline.
    $betaSource = (& git show 'main:lib/pages/tools_page.dart') -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read the main branch baseline.' }
    $betaSource = $betaSource.Replace('      _initializeApod();', '').Replace('      _loadPdfHistory();', '').Replace('      _refreshDefaultOutputDirectory();', '')
    Set-Content -LiteralPath $betaBeforePath -Value $betaSource -Encoding utf8
    New-Item -ItemType Directory -Force -Path (Join-Path $betaRoot '_tmp') | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'render_tools_test.dart.txt') -Destination $betaTestPath
    & flutter test --no-pub $betaTestPath --reporter expanded
    if ($LASTEXITCODE -ne 0) { throw 'Tool page visual verification failed.' }
} finally {
    if (Test-Path -LiteralPath $betaBeforePath) { Remove-Item -LiteralPath $betaBeforePath }
    Pop-Location
}
