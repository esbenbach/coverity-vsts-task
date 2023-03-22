[CmdletBinding()]
param()

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib

Trace-VstsEnteringInvocation $MyInvocation

try {
	[string]$solution = Get-VstsInput -Name Solution
	[string]$captureSearchPath = Get-VstsInput -Name sourceSearchPath
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
	[string]$VSVersion = Get-VstsInput -Name VSVersion
	[boolean]$allCheckers = Get-VstsInput -Name allCheckers -AsBool
	[boolean]$webSecurityCheckers = Get-VstsInput -Name webSecurityCheckers -AsBool
	[boolean]$enableCallgraphMetrics = $TRUE
	[boolean]$enableParallelBuild = Get-VstsInput -Name parallelBuild -AsBool
	[boolean]$useDotNetBuild = Get-VstsInput -Name useDotnetBuild -AsBool

	# Source functions
	. "$PSScriptRoot/Functions.ps1"

    # Set the working directory.
    Assert-VstsPath -LiteralPath $cwd -PathType Container
    Write-Verbose "Setting working directory to '$cwd'."
    Set-Location $cwd

	if ($useDotNetBuild)
	{
		$msbuildPath = "dotnet msbuild"
	}
	else
	{
		if ($VSVersion)
		{
			$msbuildPath = .$PSScriptRoot\ps_modules\Resolve-MSBuild\Resolve-MSBuild.ps1 -Version $VSVersion
		}
		else
		{
			$msbuildPath = .$PSScriptRoot\ps_modules\Resolve-MSBuild\Resolve-MSBuild.ps1
		}
	}
	
	Write-Verbose "Using Build Command $msbuildPath"
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
	Write-Verbose "CaptureSearchPath : $captureSearchPath";
	
	$captureFS = "";
	if ($captureSearchPath)
	{
		$captureFS = Generate-Arguments "--fs-capture-search" $captureSearchPath
		Write-Verbose "Capture Path Args: $captureFS"
	}

	Write-Output "#################### COV-BUILD ######################"

	$parallelBuild = If ($enableParallelBuild) {"-m" } Else { $null }

	$covBuildCmd = "$covBinPath/cov-build.exe"
	Write-Verbose "Executing Cov-Build Command: $covBuildCmd"
	& $PSScriptRoot\EchoArgs.exe --append-log --dir $intermediate $captureFS.Split(" ") $msbuildPath $solution /p:SkipInvalidConfigurations=true /p:Configuration=$configuration /p:Platform=$platform $parallelBuild $covbuildargs
	& $covBuildCmd --append-log --dir $intermediate $captureFS.Split(" ") $msbuildPath $solution  /p:SkipInvalidConfigurations=true /p:Configuration=$configuration /p:Platform=$platform $parallelBuild $covbuildargs.Split(" ")

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

	# Generate checker argument strings - this is rather convoluted due to the fact that I can't make heads or tails in how Powershell handles arguments
	$enableCheckersArgs = Generate-Arguments "--enable" $customCheckers
	$enableCheckersArgs = If ($customCheckers) { $enableCheckersArgs.Split(" ") } Else { $null }
	$disableCheckersArgs = Generate-Arguments "--disable" $disabledCheckers
	$disableCheckersArgs = If ($disabledCheckers) { $disableCheckersArgs.Split(" ") } Else { $null }
	$allCheckersArgs = If ($allCheckers) { "--all" } Else { $null }
	$webSecurityArgs = If ($webSecurityCheckers) { "--webapp-security" } Else { $null }
	$callgraphMetrics = If ($enableCallgraphMetrics) {"--enable-callgraph-metrics" } Else { $null }
	
	# --enable-constraint-fpp --

	# Putting it all together to avoid an insanely long argument list further down
	$userOptions =  @($allCheckersArgs, $webSecurityArgs, $callgraphMetrics, "--enable-jshint", "--report-in-minified-js") + $enableCheckersArgs + $disableCheckersArgs
	$userOptions = $userOptions | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

	$covAnalyzeCmd = "$covBinPath/cov-analyze.exe"
	Write-Verbose "Executing Cov-Analyze Command: $covAnalyzeCmd --dir '$intermediate' $userOptions $extraAnalyzerArgs --strip-path '$cwd' $covanalyzeargs"
	& $PSScriptRoot\EchoArgs.exe --dir $intermediate $extraAnalyzerArgs $userOptions --strip-path "$cwd" $covanalyzeargs
	& $covAnalyzeCmd --dir $intermediate $extraAnalyzerArgs $userOptions --strip-path "$cwd" $covanalyzeargs.Split(" ")

	#Exit-OnError

	Write-Output "#################### COV-DEFECTS ####################"

	$covCommitCmd = "$covBinPath/cov-commit-defects.exe"
	Write-Verbose "Excuting Cov-Commit-Defects Command: $covCommitCmd"
	& $PSScriptRoot\EchoArgs.exe --dir $intermediate --stream "$stream" --auth-key-file "$authKeyFile" --url "http://${hostname}:$port" $covcommitargs
	& $covCommitCmd --dir $intermediate --stream "$stream" --auth-key-file "$authKeyFile" --url "http://${hostname}:$port" $covcommitargs.Split(" ")

	#Exit-OnError
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}