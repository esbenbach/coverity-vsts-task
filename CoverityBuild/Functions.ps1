<#
.SYNOPSIS
Generates a command line argument string from an argument and a multiline string

.DESCRIPTION
This function takes any type of argument, and a newline delimited string, and creates a string that basically appends the argument to each line in the string.

.PARAMETER argument
The command line argument to prepend, such as --enable

.PARAMETER input
The newline delimited string to preprend the argument on

.EXAMPLE
$myArgument = "--echo";
$myThingsToEcho = "This`nIs`nAwesome"
$output = Generate-Arguments $myArgument $myThingsToEcho
Write-Host $output

Would output "--echo This --echo Is --echo Awesome"

.OUTPUTS string
#>
function Generate-Arguments {
	[CmdletBinding()]
    param(
         [Parameter(Mandatory = $true)]
        [string]$argument,
        [Parameter(Mandatory = $false)]
        [string]$input = "")

	if (-not $input)
	{
		Write-Verbose "No input given for $argument returning null"
		return $null
	}

	$splitInput = "$input".Replace("`r`n", "`n").Split("`n")

	If ($splitInput.Count -eq 0)
	{
		Write-Verbose "Input was just an empty string, returning null"
		return ""
	}

	$output = $splitInput -join " $argument "
	Write-Verbose "Returning $argument $output"
	return "$argument $output"
}

function Exit-OnError()
{
	if ($? -ne 0)
	{
		Write-Host "Exiting because previous command failed."
		exit $?
	}
}