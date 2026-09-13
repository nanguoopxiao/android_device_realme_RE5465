# SPDX-License-Identifier: Apache-2.0
# Windows PowerShell 5.1+, no Python or Recovery UI required.
[CmdletBinding()]
param(
    [string]$PackageDirectory = '',
    [string]$Serial,
    [ValidateSet('', 'RMX3551')][string]$Model = '',
    [switch]$Execute,
    [switch]$PackageOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Script parameter defaults can see the caller's PSScriptRoot in Windows
# PowerShell. Resolve the default after entering this script instead.
if (-not $PackageDirectory) { $PackageDirectory = $PSScriptRoot }
$script:Order = @('super', 'boot_a', 'vendor_boot_a', 'dtbo_a', 'recovery_a',
    'vbmeta_system_a', 'vbmeta_vendor_a', 'vbmeta_a')
$script:Sizes = @{
    super = 11274289152L; boot_a = 201326592L; vendor_boot_a = 201326592L
    dtbo_a = 25165824L; recovery_a = 104857600L
    vbmeta_system_a = 65536L; vbmeta_vendor_a = 65536L; vbmeta_a = 65536L
}
$script:ToolRoot = ''
$script:LogPath = ''

function ConvertTo-NativeArgument([string]$Value) {
    # CommandLineToArgvW quoting, including trailing backslashes before a quote.
    if ($Value -notmatch '[\s"]' -and $Value.Length -gt 0) { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Write-FlashLog([string]$Text) {
    Write-Host $Text
    if ($script:LogPath) {
        [IO.File]::AppendAllText($script:LogPath, $Text + [Environment]::NewLine)
    }
}

function Test-FlashToolOutput([string]$Tool, [int]$ExitCode, [string]$Output) {
    if ($ExitCode -ne 0 -or $Output -match '(?im)\bFAILED\b|^fastboot: error:') {
        throw "$Tool failed (exit ${ExitCode}):`n$Output"
    }
}

function Invoke-FlashTool([string]$Tool, [string[]]$Arguments, [int]$Timeout = 30) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $script:ToolRoot ($Tool + '.exe')
    $info.Arguments = ($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        if (-not $process.Start()) { throw "Could not start $Tool" }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($Timeout * 1000)) {
            $process.Kill()
            $process.WaitForExit()
            throw "$Tool timed out. Stop here and inspect the USB connection."
        }
        $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        if ($script:LogPath) {
            [IO.File]::AppendAllText($script:LogPath,
                "$Tool $($info.Arguments)`r`n$output`r`n")
        }
        Test-FlashToolOutput $Tool $process.ExitCode $output
        return $output.Trim()
    } finally { $process.Dispose() }
}

function Get-FlashVariable([string]$DeviceSerial, [string]$Name) {
    $output = Invoke-FlashTool 'fastboot' @('-s', $DeviceSerial, 'getvar', $Name)
    return ConvertFrom-FastbootVariable $Name $output
}

function ConvertFrom-FastbootVariable([string]$Name, [string]$Output) {
    $pattern = '(?m)^(?:\(bootloader\)[ \t]*)?' + [regex]::Escape($Name) + ':[ \t]*([^\r\n]*)\r?$'
    $match = [regex]::Match($Output, $pattern)
    if (-not $match.Success) { throw "Cannot read bootloader variable: $Name" }
    return $match.Groups[1].Value.Trim()
}

function ConvertTo-ByteCount([string]$Value) {
    if ($Value -match '^0x[0-9a-fA-F]+$') { return [Convert]::ToInt64($Value.Substring(2), 16) }
    if ($Value -match '^[0-9]+$') { return [Convert]::ToInt64($Value, 10) }
    throw "Invalid byte count: $Value"
}

function Get-ExpandedSize([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $header = New-Object byte[] 28
        $count = $stream.Read($header, 0, 28)
        if ($count -ge 4 -and [BitConverter]::ToUInt32($header, 0) -eq 0xed26ff3aL) {
            if ($count -ne 28 -or [BitConverter]::ToUInt16($header, 4) -ne 1 -or
                [BitConverter]::ToUInt16($header, 8) -lt 28) { throw 'Invalid sparse header' }
            $block = [BitConverter]::ToUInt32($header, 12)
            $blocks = [BitConverter]::ToUInt32($header, 16)
            if ($block -ne 4096 -or $blocks -eq 0) { throw 'Unsupported sparse geometry' }
            return [int64]$block * [int64]$blocks
        }
        return $stream.Length
    } finally { $stream.Dispose() }
}

function Read-FlashPackage([string]$Directory) {
    $root = (Resolve-Path -LiteralPath $Directory).Path
    $manifest = Get-Content -LiteralPath (Join-Path $root 'flash-manifest.json') -Raw | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.device.model -cne 'RMX3551' -or
        $manifest.device.project -cne '21605' -or $manifest.device.platform -cne 'taro' -or
        $manifest.target_slot -cne 'a' -or $manifest.install_mode -cne 'clean-install' -or
        $manifest.avb_chain_verified -ne $true -or $manifest.private_adb_keys -ne $false) {
        throw 'Unsupported or unverified package manifest'
    }
    if ($manifest.status -notin @('community-test', 'release')) { throw 'Package is not ready for flashing' }
    $rows = @($manifest.images)
    if ($rows.Count -ne $script:Order.Count) { throw 'The package must contain exactly eight images' }
    $files = @{}
    foreach ($partition in $script:Order) {
        $matches = @($rows | Where-Object { $_.partition -ceq $partition })
        if ($matches.Count -ne 1) { throw "Missing or duplicate image: $partition" }
        $row = $matches[0]
        $expected = 'images/' + ($partition -replace '_a$', '') + '.img'
        if ($row.file -cne $expected) { throw "Unexpected image path: $partition" }
        $files[$partition] = Join-Path $root $row.file
        Test-PackageFile $root $row
        $expanded = Get-ExpandedSize $files[$partition]
        if ($expanded -ne [int64]$row.expanded_bytes -or
            $expanded -gt $script:Sizes[$partition] -or $expanded -le 0) {
            throw "Image geometry mismatch: $partition"
        }
        if ($partition -eq 'super' -and $expanded -ne $script:Sizes.super) {
            throw 'Super image must describe the complete physical partition'
        }
    }
    $toolRows = @($manifest.tools)
    $toolNames = @('adb.exe', 'fastboot.exe', 'AdbWinApi.dll', 'AdbWinUsbApi.dll',
        'mke2fs.exe', 'mke2fs.conf', 'make_f2fs.exe', 'make_f2fs_casefold.exe', 'libwinpthread-1.dll')
    foreach ($name in $toolNames) {
        $matches = @($toolRows | Where-Object { $_.file -ceq ('platform-tools/' + $name) })
        if ($matches.Count -ne 1) { throw "Missing or duplicate platform tool: $name" }
        Test-PackageFile $root $matches[0]
    }
    return @{ Root = $root; Manifest = $manifest; Files = $files }
}

function Test-PackageFile([string]$Root, $Row) {
    if ($Row.file -notmatch '^(images/[a-z_]+\.img|platform-tools/[A-Za-z0-9_.-]+)$' -or
        $Row.sha256 -notmatch '^[0-9a-f]{64}$' -or [int64]$Row.bytes -le 0) {
        throw 'Invalid file entry in manifest'
    }
    $path = Join-Path $Root $Row.file
    $file = Get-Item -LiteralPath $path
    $parent = Get-Item -LiteralPath $file.DirectoryName
    if ($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        ($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        $file.Length -ne [int64]$Row.bytes) { throw "File type/length mismatch: $($Row.file)" }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $Row.sha256) {
        throw "SHA-256 mismatch: $($Row.file)"
    }
    Write-FlashLog "Verified $($Row.file)"
}

function Select-Device([string]$Output, [string]$State, [string]$RequestedSerial) {
    $devices = @([regex]::Matches($Output, '(?m)^([A-Za-z0-9][A-Za-z0-9._:-]*)\s+' + $State + '(?:\s|$)') |
        ForEach-Object { $_.Groups[1].Value })
    if ($RequestedSerial) {
        if ($RequestedSerial -in $devices) { return $RequestedSerial }
        return ''
    }
    if ($devices.Count -gt 1) { throw 'Multiple phones detected. Disconnect the others or specify -Serial.' }
    if ($devices.Count -eq 1) { return $devices[0] }
    return ''
}

function Test-Bootloader([string]$DeviceSerial) {
    foreach ($name in @('product', 'is-userspace', 'unlocked', 'slot-count', 'current-slot')) {
        $value = Get-FlashVariable $DeviceSerial $name
        switch ($name) {
            'product' { if ($value -cne 'taro') { throw 'Wrong platform' } }
            'is-userspace' { if ($value -ne 'no') { throw 'Use Bootloader Fastboot, not fastbootd' } }
            'unlocked' { if ($value -notin @('yes', 'true')) { throw 'Bootloader is locked' } }
            'slot-count' { if ($value -ne '2') { throw 'Unexpected slot layout' } }
            'current-slot' { if ($value -notin @('a', 'b')) { throw 'Invalid current slot' } }
        }
    }
    foreach ($partition in $script:Order) {
        $size = ConvertTo-ByteCount (Get-FlashVariable $DeviceSerial ('partition-size:' + $partition))
        if ($size -ne $script:Sizes[$partition]) { throw "Partition layout mismatch: $partition" }
    }
    if ((Get-FlashVariable $DeviceSerial 'partition-type:metadata') -cne 'ext4' -or
        (Get-FlashVariable $DeviceSerial 'partition-type:userdata') -cne 'f2fs' -or
        (ConvertTo-ByteCount (Get-FlashVariable $DeviceSerial 'partition-size:metadata')) -ne 16777216L -or
        (ConvertTo-ByteCount (Get-FlashVariable $DeviceSerial 'partition-size:userdata')) -le 0) {
        throw 'Unexpected data partition layout'
    }
    $maximum = ConvertTo-ByteCount (Get-FlashVariable $DeviceSerial 'max-download-size')
    $chunk = [Math]::Min(512L * 1024 * 1024, $maximum)
    $chunk = [int64]([Math]::Floor($chunk / (1024 * 1024))) * 1024 * 1024
    if ($chunk -lt 64L * 1024 * 1024) { throw 'Bootloader download buffer is too small' }
    return [string]$chunk
}

function New-FlashPlan($Package, [string]$DeviceSerial, [string]$ChunkBytes) {
    $plan = New-Object Collections.Generic.List[object]
    foreach ($partition in $script:Order) {
        $plan.Add(@('-s', $DeviceSerial, '-S', $ChunkBytes, 'flash', $partition, $Package.Files[$partition]))
    }
    $plan.Add(@('-s', $DeviceSerial, 'format:ext4', 'metadata'))
    $plan.Add(@('-s', $DeviceSerial, 'format:f2fs', 'userdata'))
    $plan.Add(@('-s', $DeviceSerial, 'set_active', 'a'))
    $plan.Add(@('-s', $DeviceSerial, 'reboot'))
    return ,$plan
}

function Invoke-FlashPlan($Plan) {
    foreach ($command in $Plan) {
        Write-FlashLog ('Running fastboot ' + (($command | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '))
        Write-FlashLog (Invoke-FlashTool 'fastboot' $command 1800)
    }
}

function Start-Re5465Flash {
    if ($Execute -and $PackageOnly) { throw '-PackageOnly cannot be combined with -Execute' }
    $package = Read-FlashPackage $PackageDirectory
    $script:ToolRoot = Join-Path $package.Root 'platform-tools'
    Write-FlashLog "Build: $($package.Manifest.build_id) / $($package.Manifest.status)"
    Write-FlashLog 'Clean installation: all apps, photos and other user data will be erased.'
    Write-FlashLog 'Target: realme GT2 Master Explorer RMX3551, project 21605 only.'
    if ($PackageOnly) { Write-FlashLog 'Package verified. No device commands were sent.'; return }

    $deviceSerial = Select-Device (Invoke-FlashTool 'fastboot' @('devices')) 'fastboot' $Serial
    $identityVerified = $false
    if (-not $deviceSerial) {
        $deviceSerial = Select-Device (Invoke-FlashTool 'adb' @('devices')) 'device' $Serial
        if (-not $deviceSerial) { throw 'No authorized ADB device or Fastboot device. Check cable and driver.' }
        $project = Invoke-FlashTool 'adb' @('-s', $deviceSerial, 'shell', 'getprop', 'ro.boot.prjname')
        $platform = Invoke-FlashTool 'adb' @('-s', $deviceSerial, 'shell', 'getprop', 'ro.board.platform')
        if ($project -cne '21605' -or $platform -cne 'taro') { throw 'ADB hardware identity does not match RMX3551' }
        $identityVerified = $true
        if (-not $Execute) {
            Write-FlashLog 'ADB hardware identity verified. Bootloader checks will run during installation.'
            return
        }
        Write-FlashLog 'Rebooting the verified device into Bootloader Fastboot.'
        Invoke-FlashTool 'adb' @('-s', $deviceSerial, 'reboot', 'bootloader') | Out-Null
        $deadline = [DateTime]::UtcNow.AddSeconds(45)
        do {
            Start-Sleep -Milliseconds 500
            $found = Select-Device (Invoke-FlashTool 'fastboot' @('devices')) 'fastboot' $deviceSerial
        } until ($found -or [DateTime]::UtcNow -gt $deadline)
        if (-not $found) { throw 'Same phone did not appear in Fastboot. Check its cable/driver.' }
    }
    # This bootloader's product=taro is shared with other phones. Never treat it
    # as model proof. A Fastboot-only start needs an explicit physical-model check.
    if (-not $identityVerified -and $Model -cne 'RMX3551') {
        if (-not $Execute) { throw 'Fastboot-only identity needs -Model RMX3551 after checking the physical model.' }
        $answer = Read-Host 'Check the physical model. Type RMX3551 to confirm GT2 Master Explorer (not GT2/GT2 Pro)'
        if ($answer -cne 'RMX3551') { throw 'Model was not confirmed' }
    }
    $chunk = Test-Bootloader $deviceSerial
    $plan = New-FlashPlan $package $deviceSerial $chunk
    foreach ($command in $plan) { Write-FlashLog ('PLAN fastboot ' + ($command -join ' ')) }
    if (-not $Execute) { Write-FlashLog 'Checks passed. No partitions were written.'; return }
    $answer = Read-Host 'This will ERASE ALL PHONE DATA. Type ERASE RMX3551 to install'
    if ($answer -cne 'ERASE RMX3551') { throw 'Installation cancelled before partition writes' }
    $logDirectory = Join-Path $package.Root 'logs'
    [IO.Directory]::CreateDirectory($logDirectory) | Out-Null
    $script:LogPath = Join-Path $logDirectory ('flash-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
    Invoke-FlashPlan $plan
    Write-FlashLog 'All flash commands succeeded; reboot requested. Android startup still needs observation.'
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Start-Re5465Flash; exit 0 }
    catch { Write-Host ("STOPPED: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
}
