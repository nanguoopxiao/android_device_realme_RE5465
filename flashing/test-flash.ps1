# SPDX-License-Identifier: Apache-2.0
# These tests replace all device I/O. Never run a flash command on a real phone.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flash.ps1')
$script:Passed = 0

function Assert-Equal($Actual, $Expected, [string]$Name) {
    if ($Actual -cne $Expected) { throw "$Name : expected [$Expected], got [$Actual]" }
    $script:Passed++
}
function Assert-Fails([scriptblock]$Action, [string]$Message) {
    $caught = $false
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -notlike ('*' + $Message + '*')) { throw }
        $caught = $true
    }
    if (-not $caught) { throw "Expected failure containing $Message" }
    $script:Passed++
}

Assert-Equal (ConvertTo-NativeArgument 'C:\space here\') '"C:\space here\\"' 'Trailing slash quoting'
Assert-Equal (ConvertTo-NativeArgument 'a"b') '"a\"b"' 'Quote escaping'
Assert-Equal (ConvertTo-NativeArgument '') '""' 'Empty argument'
Assert-Equal (ConvertTo-ByteCount '0x2a0000000') 11274289152L '64-bit partition size'
Assert-Fails { ConvertTo-ByteCount '12M' } 'Invalid byte count'
Assert-Fails { Test-FlashToolOutput 'fastboot' 0 'FAILED (remote: rejected)' } 'failed'
Assert-Fails { Test-FlashToolOutput 'fastboot' 1 'unusual error' } 'failed'
Assert-Fails { Test-FlashToolOutput 'fastboot' 0 'fastboot: error: USB failure' } 'failed'
Assert-Equal (ConvertFrom-FastbootVariable 'product' "product: taro`r`nFinished. Total time: 0.032s`r`n") 'taro' 'Windows CRLF getvar'
Assert-Equal (ConvertFrom-FastbootVariable 'product' "(bootloader) product: taro`nFinished.") 'taro' 'Bootloader prefix and LF'
Assert-Fails { ConvertFrom-FastbootVariable 'product' 'Finished.' } 'Cannot read bootloader variable'
Assert-Fails { Select-Device "one`tfastboot`ntwo`tfastboot" 'fastboot' '' } 'Multiple phones'
Assert-Equal (Select-Device "one`tunauthorized" 'device' '') '' 'Reject unauthorized ADB'
Assert-Equal (Select-Device "one`tfastboot`ntwo`tfastboot" 'fastboot' 'two') 'two' 'Explicit serial selection'

$script:Variables = @{
    product = 'taro'; 'is-userspace' = 'no'; unlocked = 'yes'; 'slot-count' = '2'; 'current-slot' = 'b'
    'partition-type:metadata' = 'ext4'; 'partition-type:userdata' = 'f2fs'
    'partition-size:metadata' = '0x1000000'; 'partition-size:userdata' = '0x37F450F000'
    'max-download-size' = '0x30000000'
}
foreach ($name in $script:Order) { $script:Variables['partition-size:' + $name] = [string]$script:Sizes[$name] }
function Get-FlashVariable([string]$DeviceSerial, [string]$Name) {
    if (-not $script:Variables.ContainsKey($Name)) { throw "Mock variable missing: $Name" }
    return $script:Variables[$Name]
}
Assert-Equal (Test-Bootloader 'mock') '536870912' 'Choose 512 MiB chunks'
$script:Variables['max-download-size'] = '0x10000000'
Assert-Equal (Test-Bootloader 'mock') '268435456' 'Respect a smaller download buffer'
$script:Variables['partition-size:userdata'] = '0x77F450F000'
Assert-Equal (Test-Bootloader 'mock') '268435456' 'No storage-variant userdata constant'
$script:Variables['unlocked'] = 'no'
Assert-Fails { Test-Bootloader 'mock' } 'Bootloader is locked'
$script:Variables['unlocked'] = 'yes'
$script:Variables['is-userspace'] = 'yes'
Assert-Fails { Test-Bootloader 'mock' } 'not fastbootd'
$script:Variables['is-userspace'] = 'no'
$script:Variables['partition-size:super'] = '1024'
Assert-Fails { Test-Bootloader 'mock' } 'Partition layout mismatch'
$script:Variables['partition-size:super'] = '11274289152'

$package = @{ Files = @{} }
foreach ($name in $script:Order) { $package.Files[$name] = 'C:\package with spaces\images\' + $name + '.img' }
$plan = New-FlashPlan $package 'mock' '268435456'
Assert-Equal $plan.Count 12 'Full installation command count'
Assert-Equal ($plan[0] -join '|') '-s|mock|-S|268435456|flash|super|C:\package with spaces\images\super.img' 'Super first'
Assert-Equal ($plan[8] -join '|') '-s|mock|format:ext4|metadata' 'Format metadata'
Assert-Equal ($plan[9] -join '|') '-s|mock|format:f2fs|userdata' 'Format userdata'
Assert-Equal ($plan[10] -join '|') '-s|mock|set_active|a' 'Select package bootstrap slot'
Assert-Equal ($plan[11] -join '|') '-s|mock|reboot' 'Reboot last'
$script:Calls = New-Object Collections.Generic.List[object]
function Invoke-FlashTool([string]$Tool, [string[]]$Arguments, [int]$Timeout = 30) {
    $script:Calls.Add($Arguments)
    if ($script:Calls.Count -eq 3) { throw 'Mock cable failure' }
    return 'OKAY'
}
Assert-Fails { Invoke-FlashPlan $plan } 'Mock cable failure'
Assert-Equal $script:Calls.Count 3 'Stop on first failed write; no wipe or reboot afterwards'

$fixture = Join-Path $PSScriptRoot ('.test-work-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory((Join-Path $fixture 'images')) | Out-Null
try {
    $nestedPackage = Join-Path $fixture 'package with spaces'
    [IO.Directory]::CreateDirectory($nestedPackage) | Out-Null
    $nestedScript = Join-Path $nestedPackage 'flash.ps1'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'flash.ps1') -Destination $nestedScript
    # A separate command caller has no PSScriptRoot. Dot-sourcing keeps this
    # path regression isolated from all device operations and from our mocks.
    $quotedScript = "'" + $nestedScript.Replace("'", "''") + "'"
    $probe = '. ' + $quotedScript + ' -PackageOnly; [Console]::Out.Write($PackageDirectory)'
    $defaultDirectory = & powershell.exe -NoLogo -NoProfile -NonInteractive -Command $probe
    Assert-Equal $LASTEXITCODE 0 'Default-directory probe exits normally'
    Assert-Equal $defaultDirectory $nestedPackage 'Default directory belongs to flash.ps1, not its caller'
    $overrideDirectory = Join-Path $fixture 'explicit package'
    $quotedOverride = "'" + $overrideDirectory.Replace("'", "''") + "'"
    $probe = '. ' + $quotedScript + ' -PackageOnly -PackageDirectory ' + $quotedOverride + '; [Console]::Out.Write($PackageDirectory)'
    $actualOverride = & powershell.exe -NoLogo -NoProfile -NonInteractive -Command $probe
    Assert-Equal $LASTEXITCODE 0 'Explicit-directory probe exits normally'
    Assert-Equal $actualOverride $overrideDirectory 'Preserve an explicit package directory'
    $path = Join-Path $fixture 'images/super.img'
    $header = New-Object byte[] 28
    [BitConverter]::GetBytes([uint32]0xed26ff3aL).CopyTo($header, 0)
    [BitConverter]::GetBytes([uint16]1).CopyTo($header, 4)
    [BitConverter]::GetBytes([uint16]28).CopyTo($header, 8)
    [BitConverter]::GetBytes([uint32]4096).CopyTo($header, 12)
    [BitConverter]::GetBytes([uint32]2752512).CopyTo($header, 16)
    [IO.File]::WriteAllBytes($path, $header)
    Assert-Equal (Get-ExpandedSize $path) 11274289152L 'Sparse expanded size, not compressed length'
    $row = @{file='images/super.img'; bytes=28; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
    Test-PackageFile $fixture $row
    [IO.Directory]::CreateDirectory((Join-Path $fixture 'platform-tools')) | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $fixture 'platform-tools/libwinpthread-1.dll'), $header)
    Test-PackageFile $fixture @{file='platform-tools/libwinpthread-1.dll'; bytes=28; sha256=$row.sha256}
    $script:Passed++
    $row.sha256 = '0' * 64
    Assert-Fails { Test-PackageFile $fixture $row } 'SHA-256 mismatch'
    $row.file = '../outside.img'
    Assert-Fails { Test-PackageFile $fixture $row } 'Invalid file entry'
} finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    $expectedPrefix = [IO.Path]::GetFullPath($PSScriptRoot) + [IO.Path]::DirectorySeparatorChar + '.test-work-'
    if (-not $resolved.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing cleanup outside the exact test workspace'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
Write-Host "PASS: $script:Passed checks; no real device I/O."
