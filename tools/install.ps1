param(
    [Parameter(Mandatory=$true)]
    [string]$AddOnsPath
)
$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$parent = (Resolve-Path -LiteralPath $AddOnsPath).Path
if ((Split-Path $parent -Leaf) -ne 'AddOns') { throw 'The destination must be an existing AddOns directory.' }
$destination = [IO.Path]::GetFullPath((Join-Path $parent 'Mailwright'))
if ((Split-Path $destination -Parent) -ne $parent) { throw 'Destination validation failed.' }
$files = @('Core.lua','API.lua','Contacts.lua','Mailbox.lua','Sending.lua','UI.lua','MailboxUI.lua','FlavorForever.lua','LICENSE','README.md','TESTING.md')
$files += Get-ChildItem -LiteralPath $source -Filter 'Mailwright*.toc' | ForEach-Object { $_.Name }
foreach ($name in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $name) -PathType Leaf)) { throw "Missing source file: $name" }
}
if (Test-Path -LiteralPath $destination) {
    $backupRoot = Join-Path $source 'dist'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $backup = Join-Path $backupRoot ('Mailwright-installed-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.zip')
    # Never follow the local Forever junction into account SavedVariables.
    $backupFiles = @(Get-ChildItem -LiteralPath $destination -File | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } | ForEach-Object FullName)
    if ($backupFiles.Count -gt 0) { Compress-Archive -LiteralPath $backupFiles -DestinationPath $backup }
    Write-Output "Existing Mailwright backed up to $backup"
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach ($name in $files) {
    $from = Join-Path $source $name
    $to = Join-Path $destination $name
    if ($name -like '*.toc' -and (Test-Path -LiteralPath $to)) {
        $existing = Get-Content -LiteralPath $to -Raw
        if ($existing -match '(?m)^LocalSavedData\\Mailwright\.lua\r?$') {
            foreach ($localFile in @('LocalLoadBefore.lua','LocalLoadAfter.lua','LocalLoadFinish.lua','LocalSavedData\Mailwright.lua')) {
                if (-not (Test-Path -LiteralPath (Join-Path $destination $localFile) -PathType Leaf)) { throw "Local workaround file missing: $localFile" }
            }
            $lines = @(Get-Content -LiteralPath $from)
            $first = 0
            while ($first -lt $lines.Count -and ($lines[$first].Trim() -eq '' -or $lines[$first] -match '^#')) { $first++ }
            $patched = @('## X-Mailwright-LocalLoader: ' + $name)
            $patched += $lines[0..($first - 1)]
            $patched += @('LocalLoadBefore.lua','LocalSavedData\Mailwright.lua','LocalLoadAfter.lua')
            $patched += $lines[$first..($lines.Count - 1)]
            $patched += 'LocalLoadFinish.lua'
            $expected = ($patched -join [Environment]::NewLine) + [Environment]::NewLine
            [IO.File]::WriteAllText($to, $expected, [Text.UTF8Encoding]::new($false))
            if ([IO.File]::ReadAllText($to) -cne $expected) { throw "Manifest verification failed: $name" }
            continue
        }
    }
    Copy-Item -LiteralPath $from -Destination $to -Force
    if ((Get-FileHash -LiteralPath $from).Hash -ne (Get-FileHash -LiteralPath $to).Hash) { throw "Hash mismatch: $name" }
}
Write-Output "Installed and hash-verified $($files.Count) Mailwright files at $destination"
Write-Output 'Postal and all SavedVariables files were left intact.'

