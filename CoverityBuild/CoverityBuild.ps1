[CmdletBinding()]
param()

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib

Trace-VstsEnteringInvocation $MyInvocation

try {
    [string]$solution = Get-VstsInput -Name Solution
    [string]$platform = Get-VstsInput -Name Platform
    [string]$configuration = Get-VstsInput -Name Configuration
	[string]$hostname = Get-VstsInput -Name hostname
	[string]$port = Get-VstsInput -Name portNumber
	[string]$covBinPath = Get-VstsInput -Name coverityBinPath
	[string]$authKeyFile = Get-VstsInput -Name authKeyFile
	[string]$intermediate = Get-VstsInput -Name idir
	[string]$stream = Get-VstsInput -Name stream

    # Set the working directory.
    [string]$cwd = Get-VstsInput -Name cwd -Require
    Assert-VstsPath -LiteralPath $cwd -PathType Container
    Write-Verbose "Setting working directory to '$cwd'."
    Set-Location $cwd

	$msbuildPath = .$PSScriptRoot\ps_modules\Resolve-MSBuild\Resolve-MSBuild.ps1
	Write-Verbose "Found MsBuild at $msbuildPath"

	Write-Verbose "Input variables"
	Write-Verbose "Solution: $solution"
	Write-Verbose "Platform: $platform"
	Write-Verbose "Configuration: $configuration"
	Write-Verbose "Host: $hostname"
	Write-Verbose "Port: $port"
	Write-Verbose "Cov Bin Path: $covBinPath"
	Write-Verbose "AuthKey: $authKeyFile"
	Write-Verbose "Intermediate: $intermediate"
	Write-Verbose "Stream: $stream"

	$covBuildCmd = "$covBinPath/cov-build.exe"
	Write-Verbose "Executing Cov-Build Command: $covBuildCmd"
	& $covBuildCmd --append-log --dir $intermediate $msbuildPath $solution /p:SkipInvalidConfigurations=true /p:Configuration=$configuration /p:Platform=$platform /m

	$covAnalyzeCmd = "$covBinPath/cov-analyze.exe"
	Write-Verbose "Executing Cov-Analyze Command: $covAnalyzeCmd"
	& $covAnalyzeCmd --dir "$intermediate" --strip-path "$cwd"

	$covCommitCmd = "$covBinPath/cov-commit-defects.exe"
	Write-Verbose "Excuting Cov-Commit-Defects Command: $covCommitCmd"
	& $covCommitCmd  --dir "$intermediate" --stream "$stream" --auth-key-file "$authKeyFile" --host $hostname --port $port
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}