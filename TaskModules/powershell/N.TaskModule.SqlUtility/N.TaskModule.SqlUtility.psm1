[CmdletBinding()]
param(
    [ValidateNotNull()]
    [Parameter()]
    [hashtable]$ModuleParameters = @{ })

if ($host.Name -notin "ConsoleHost","Default Host") {
    Write-Warning "N.TaskModule.SqlUtility is designed for use with powershell.exe (ConsoleHost). Output may be different when used with other hosts."
}

# Private module variables.
[bool]$script:nonInteractive = "$($ModuleParameters['NonInteractive'])" -eq 'true'
Write-Verbose "NonInteractive: $script:nonInteractive"

# Import/export functions.
. "$PSScriptRoot\JobManager.ps1"
. "$PSScriptRoot\SqlPackageOnTargetMachines.ps1"
. "$PSScriptRoot\SqlQueryOnTargetMachines.ps1"

Export-ModuleMember -Function @(
        'Invoke-SqlQueryDeployment',
        'Invoke-DacpacDeployment',
		'Invoke-CommandLine'
    )

# Special internal exception type to control the flow. Not currently intended
# for public usage and subject to change. If the type has already
# been loaded once, then it is not loaded again.
Write-Verbose "Adding exceptions types."
Add-Type -WarningAction SilentlyContinue -Debug:$false -TypeDefinition @'
namespace N.TaskModule.SqlUtility
{
    public class TerminationException : System.Exception
    {
        public TerminationException(System.String message) : base(message) { }
    }
}
'@
