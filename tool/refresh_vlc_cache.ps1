<#
.SYNOPSIS
  Regenerates libVLC's plugins.dat for the built Windows app.

.DESCRIPTION
  Without a valid plugins.dat, libvlc_new() rebuilds its module bank by
  loading every DLL under plugins/ (~365 files). That costs ~200 ms with a
  warm file cache and ~20 s cold, on the Flutter platform thread.

  windows/CMakeLists.txt generates this cache as an install step, but MSBuild
  runs the vlc_player plugin's copy_directory targets in parallel and can
  finish copying DLLs after the cache is written -- libVLC then rejects it
  ("stale plugins cache: modified ..."). Run this after a build to fix that
  up; it is ordering-proof because nothing else is running.

.EXAMPLE
  pwsh tool/refresh_vlc_cache.ps1
  pwsh tool/refresh_vlc_cache.ps1 -Config Release
#>
param(
    [ValidateSet('Debug', 'Profile', 'Release')]
    [string]$Config = 'Debug'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

$pluginsDir = Join-Path $repo "build\windows\x64\runner\$Config\plugins"
if (-not (Test-Path $pluginsDir)) {
    Write-Error "No plugins directory at $pluginsDir. Build the Windows app first."
}

# The VLC runtime is downloaded into a version-stamped directory, so discover
# the generator rather than pinning a version.
$searchRoot = Join-Path $repo 'build\windows\x64\plugins\vlc_player\vlc'
$gen = Get-ChildItem -Path $searchRoot -Filter 'vlc-cache-gen.exe' -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($null -eq $gen) {
    Write-Error "vlc-cache-gen.exe not found under $searchRoot."
}

$cacheFile = Join-Path $pluginsDir 'plugins.dat'
$dlls = Get-ChildItem -Path $pluginsDir -Filter '*.dll' -Recurse
if (Test-Path $cacheFile) {
    $cacheTime = (Get-Item $cacheFile).LastWriteTimeUtc
    $staleBefore = @($dlls | Where-Object { $_.LastWriteTimeUtc -gt $cacheTime }).Count
    Write-Host "Before: $staleBefore of $($dlls.Count) plugins newer than the cache."
    Remove-Item $cacheFile -Force
} else {
    Write-Host "Before: no plugins.dat present."
}

# vlc-cache-gen only indexes anything when VLC_PLUGIN_PATH points at the same
# directory it is given -- with the argument alone it writes an empty 24-byte
# cache. This must match the path the plugin sets at runtime.
$env:VLC_PLUGIN_PATH = $pluginsDir
& $gen.FullName $pluginsDir
if ($LASTEXITCODE -ne 0) {
    Write-Error "vlc-cache-gen failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path $cacheFile)) {
    Write-Error 'vlc-cache-gen reported success but wrote no cache.'
}

$cacheTime = (Get-Item $cacheFile).LastWriteTimeUtc
$staleAfter = @(Get-ChildItem -Path $pluginsDir -Filter '*.dll' -Recurse |
    Where-Object { $_.LastWriteTimeUtc -gt $cacheTime }).Count
$sizeKb = [math]::Round((Get-Item $cacheFile).Length / 1KB)
Write-Host "After:  $staleAfter stale, cache is $sizeKb KB ($Config)."
