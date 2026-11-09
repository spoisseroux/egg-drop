param([string]$OutputPath = 'artifacts/item-eggs-aero-2026-11-09/source-manifest.json')
$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$target = if ([System.IO.Path]::IsPathRooted($OutputPath)) { [System.IO.Path]::GetFullPath($OutputPath) } else { [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath)) }
if (-not $target.StartsWith($repoRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Manifest output must stay inside the Egg Drop repository.' }
$sha = [System.Security.Cryptography.SHA256]::Create()
function Get-SourceEntry([string]$file) {
    $relative = $file.Substring($repoRoot.Length + 1).Replace('\', '/')
    $text = [System.IO.File]::ReadAllText($file).TrimStart([char]0xFEFF).Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $hash = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
    $entry = [ordered]@{ path = $relative; sha256 = $hash; utf8Bytes = $bytes.Length; modifiedUtcTicks = (Get-Item -LiteralPath $file).LastWriteTimeUtc.Ticks }
    if ($relative.StartsWith('src/')) {
        $pieces = $relative.Split('/')
        $root = switch ($pieces[1]) { 'shared' { 'ReplicatedStorage.Shared' }; 'server' { 'ServerScriptService.Server' }; 'client' { 'StarterPlayer.StarterPlayerScripts.Client' }; default { throw "Unknown runtime group: $relative" } }
        $entry['dataModelPath'] = if ($pieces[2] -in @('init.lua', 'init.server.lua', 'init.client.lua')) { $root } else { $root + '.' + [System.IO.Path]::GetFileNameWithoutExtension($pieces[2]) }
    }
    return $entry
}
try {
    $started = [DateTime]::UtcNow
    $runtime = @(& rg --files (Join-Path $repoRoot 'src') -g '*.lua' | Sort-Object | ForEach-Object { Get-SourceEntry ([System.IO.Path]::GetFullPath($_)) })
    $specs = @(& rg --files (Join-Path $repoRoot 'scripts') -g '*.spec.lua' | Sort-Object | ForEach-Object { Get-SourceEntry ([System.IO.Path]::GetFullPath($_)) })
    $stable = $true
    foreach ($entry in @($runtime) + @($specs)) { if ((Get-Item -LiteralPath (Join-Path $repoRoot $entry.path)).LastWriteTimeUtc.Ticks -ne $entry.modifiedUtcTicks) { $stable = $false } }
    $manifest = [ordered]@{
        schema = 1; generatedUtc = [DateTime]::UtcNow.ToString('o'); startedUtc = $started.ToString('o'); stableDuringCapture = $stable
        status = 'Source snapshot only. This file does not certify native equality, tests or publication.'
        branch = (& git -C $repoRoot branch --show-current); head = (& git -C $repoRoot rev-parse HEAD)
        normalization = 'Read UTF-8, strip leading BOM, normalize CRLF/CR to LF, preserve trailing newlines; SHA-256 of UTF-8 bytes.'
        placeId = '96451847774961'; project = 'default.project.json'; runtimeSourceCount = $runtime.Count; specSourceCount = $specs.Count
        projectSource = (Get-SourceEntry (Join-Path $repoRoot 'default.project.json')); runtimeSources = $runtime; specSources = $specs
    }
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target)) | Out-Null
    [System.IO.File]::WriteAllText($target, ($manifest | ConvertTo-Json -Depth 12), [System.Text.UTF8Encoding]::new($false))
    [ordered]@{ path = $target; runtimeSources = $runtime.Count; specs = $specs.Count; stableDuringCapture = $stable } | ConvertTo-Json -Compress
} finally { $sha.Dispose() }
