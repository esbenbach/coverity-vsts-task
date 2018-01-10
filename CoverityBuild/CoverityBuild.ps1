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
	[boolean]$enableScmImport = Get-VstsInput -Name enableScmImport -AsBool
	[string]$scmType = Get-VstsInput -Name scmType
	[string]$covbuildargs = Get-VstsInput -Name covbuildargs
	[string]$covanalyzeargs = Get-VstsInput -Name covanalyzeargs
	[string]$covcommitargs = Get-VstsInput -Name covcommitargs
	[string]$covscmargs = Get-VstsInput -Name covscmargs
	[string]$cwd = Get-VstsInput -Name cwd -Require
	[string]$customCheckers = Get-VstsInput -Name customCheckers
	[string]$disabledCheckers = Get-VstsInput -Name disabledCheckers
	[boolean]$allCheckers = Get-VstsInput -Name allCheckers -AsBool
	[boolean]$webSecurityCheckers = Get-VstsInput -Name webSecurityCheckers -AsBool
	[boolean]$webSecurityPreviewCheckers = Get-VstsInput -Name webSecurityPreviewCheckers -AsBool
	[boolean]$enableCallgraphMetrics = $TRUE

	# Source functions
	. "$PSScriptRoot/Functions.ps1"

    # Set the working directory.
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

	Write-Output "#################### COV-BUILD ######################"

	$covBuildCmd = "$covBinPath/cov-build.exe"
	Write-Verbose "Executing Cov-Build Command: $covBuildCmd"
	& $PSScriptRoot\EchoArgs.exe --append-log --dir $intermediate $msbuildPath $solution /p:SkipInvalidConfigurations=true /p:Configuration=$configuration /p:Platform=$platform $covbuildargs
	& $covBuildCmd --append-log --dir $intermediate $msbuildPath $solution /p:SkipInvalidConfigurations=true /p:Configuration=$configuration /p:Platform=$platform $covbuildargs.Split(" ")

	if ($enableScmImport)
	{
		Write-Output "#################### COV-IMPORT-SCM ######################"
		$covImportScmCmd = "$covBinPath/cov-import-scm.exe"
		Write-Verbose "Executing Cov-ImportScm Command: $covImportScmCmd"
		& $PSScriptRoot\EchoArgs.exe --dir $intermediate --scm $scmType $covscmargs
		& $covImportScmCmd --dir $intermediate --scm $scmType $covscmargs.Split(" ")

		#Exit-OnError
	}

	Write-Output "#################### COV-ANALYZE ####################"

	# Generate checker argument strings
	$enableCheckersArgs = Generate-Arguments "--enable" $customCheckers
	$disableCheckersArgs = Generate-Arguments "--disable" $disabledCheckers
	$allCheckersArgs = If ($allCheckers) { "--all" } Else { $null }
	$webSecurityArgs = If ($webSecurityCheckers) { "--webapp-security" } Else { $null }
	$webPreviewSecurityArgs = If ($webSecurityPreviewCheckers) { "--webapp-security-preview" } Else { $null }
	$callgraphMetrics = If ($enableCallgraphMetrics) {"--enable-callgraph-metrics" } Else { $null }

	# Putting it all together to avoid an insanely long argument list further down
	$userOptions =  @($enableCheckersArgs, $disableCheckersArgs, $allCheckersArgs, $webSecurityArgs, $webPreviewSecurityArgs)
	$userOptions = $userOptions | Where { -not [string]::IsNullOrWhiteSpace($_) }
	$allArgs = "--dir $intermediate $userOptions --strip-path '$cwd' $covanalyzeargs"

	$covAnalyzeCmd = "$covBinPath/cov-analyze.exe"
	Write-Verbose "Executing Cov-Analyze Command: $covAnalyzeCmd --dir '$intermediate' $extraAnalyzerArgs --strip-path '$cwd' $covanalyzeargs"
	& $PSScriptRoot\EchoArgs.exe --dir $intermediate $extraAnalyzerArgs --strip-path "$cwd" $covanalyzeargs
	& $covAnalyzeCmd --dir $intermediate $extraAnalyzerArgs --strip-path "$cwd" $covanalyzeargs.Split(" ")

	#Exit-OnError

	Write-Output "#################### COV-DEFECTS ####################"

	$covCommitCmd = "$covBinPath/cov-commit-defects.exe"
	Write-Verbose "Excuting Cov-Commit-Defects Command: $covCommitCmd"
	& $PSScriptRoot\EchoArgs.exe --dir $intermediate --stream "$stream" --auth-key-file "$authKeyFile" --host $hostname --port $port $covcommitargs
	& $covCommitCmd --dir $intermediate --stream "$stream" --auth-key-file "$authKeyFile" --host $hostname --port $port $covcommitargs.Split(" ")

	#Exit-OnError
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}