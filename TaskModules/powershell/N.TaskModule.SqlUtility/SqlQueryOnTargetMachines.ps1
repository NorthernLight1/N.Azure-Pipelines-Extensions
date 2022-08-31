# Function to import SqlPS module & avoid directory switch
function Import-SqlPs {
    push-location
    Import-Module SqlPS -ErrorAction 'SilentlyContinue' | out-null
    pop-location
}

function Get-SqlFilepathOnTargetMachine
{
    param([string] $inlineSql)

    $tempFilePath = [System.IO.Path]::GetTempFileName()
    ($inlineSql | Out-File $tempFilePath)

    return $tempFilePath
}

function Get-Databases
{
	param(
		[string]$serverName,
		[string[]]$databaseName,
		[string]$authscheme,
		[System.Management.Automation.PSCredential]$sqlServerCredentials,
	)
	
	$databases = New-Object Collections.Generic.List[object];
	foreach($dbName in $databaseName)
	{
		if($dbName.Contains("%"))
		{
			$dbName = $dbName -Replace "_", "[_]"
			$databasesFromQuery=Invoke-SqlQuery -Query "SELECT name FROM sys.databases WHERE state=0 AND name LIKE '$($dbName)' ORDER BY name" -serverName $serverName -databaseName $databaseName -authscheme $authscheme -sqlServerCredentials $sqlServerCredentials | Select-Object -Property name
			$databases.AddRange($databasesFromQuery)
		}
		else
		{
			$databases.Add($dbName);
		}
	}
	return $databases
}

function Invoke-SqlQueryDeployment
{
    param (
        [string]$taskType,
        [string]$sqlFile,
        [string]$inlineSql,
        [string]$serverName,
        [string]$databaseName,
        [string]$authscheme,
        [System.Management.Automation.PSCredential]$sqlServerCredentials,
        [string]$additionalArguments
    )

    Write-Verbose "Entering script SqlQueryOnTargetMachines.ps1"
    Write-Verbose "taskType = $taskType"
    Write-Verbose "sqlFile = $sqlFile"
    Write-Verbose "inlineSql = $inlineSql"
    Write-Verbose "serverName = $serverName"
    Write-Verbose "databaseName = $databaseName"
    Write-Verbose "authscheme = $authscheme"
    Write-Verbose "additionalArguments = $additionalArguments"

    try 
    {
        if($taskType -eq "sqlInline")
        {
            # Convert this inline Sql to a temporary file on Server
            $sqlFile = Get-SqlFilepathOnTargetMachine $inlineSql
        }
        else
        {
            # Validate Sql File
            if([System.IO.Path]::GetExtension($sqlFile) -ne ".sql")
            {
                throw "Invalid Sql file [ $sqlFile ] provided"
            }
        }        

        # Import SQLPS Module
        Import-SqlPs

        $spaltArguments = @{
            ServerInstance=$serverName
            Database=$databaseName
            InputFile=$sqlFile
        }

        if($authscheme -eq "sqlServerAuthentication")
        {
            if($sqlServerCredentials)
            {
                $sqlUsername = $sqlServerCredentials.Username
                $sqlPassword = $sqlServerCredentials.GetNetworkCredential().password
                $spaltArguments.Add("Username", $sqlUsername)
                $spaltArguments.Add("Password", $sqlPassword)
            }
        }

        $commandToLog = "Invoke-SqlCmd"
        foreach ($arg in $spaltArguments.Keys) {
            if($arg -ne "Password")
            {
                $commandToLog += " -${arg} $($spaltArguments.Item($arg))"
            }
            else
            {
                $commandToLog += " -${arg} *******"
            }
        }

        $additionalArguments = EscapeSpecialChars $additionalArguments

        Write-Verbose "Invoke-SqlCmd arguments : $commandToLog  $additionalArguments"
        Invoke-Expression "Invoke-SqlCmd @spaltArguments $additionalArguments"

    } # End of Try
    Finally
    {
        # Cleanup the temp file & dont error out in case Deletion fails
        if ($taskType -eq "sqlInline" -and $sqlFile -and ((Test-Path $sqlFile) -eq $true))
        {
            Write-Verbose "Removing File $sqlFile"
            Remove-Item $sqlFile -ErrorAction 'SilentlyContinue'
        }
    }
}

function Invoke-SqlQuery
{
    param (
        [string]$query,
        [string]$serverName,
        [string]$databaseName,
        [string]$authscheme,
        [System.Management.Automation.PSCredential]$sqlServerCredentials,
        [string]$additionalArguments
    )

    Write-Verbose "Entering script SqlQueryOnTargetMachines.ps1"
    Write-Verbose "serverName = $serverName"
    Write-Verbose "databaseName = $databaseName"
    Write-Verbose "authscheme = $authscheme"
    Write-Verbose "additionalArguments = $additionalArguments"

    try 
    {
		
		$sqlFile = Get-SqlFilepathOnTargetMachine $query
        # Import SQLPS Module
        Import-SqlPs

        $arguments = @{
            ServerInstance=$serverName
            Database=$databaseName
			InputFile=$sqlFile
        }

        if($authscheme -eq "sqlServerAuthentication")
        {
            if($sqlServerCredentials)
            {
                $sqlUsername = $sqlServerCredentials.Username
                $sqlPassword = $sqlServerCredentials.GetNetworkCredential().password
                $arguments.Add("Username", $sqlUsername)
                $arguments.Add("Password", $sqlPassword)
            }
        }

        $commandToLog = "Invoke-SqlCmd"
        foreach ($arg in $arguments.Keys) {
            if($arg -ne "Password")
            {
                $commandToLog += " -${arg} $($arguments.Item($arg))"
            }
            else
            {
                $commandToLog += " -${arg} *******"
            }
        }

        $additionalArguments = EscapeSpecialChars $additionalArguments

        Write-Verbose "Invoke-SqlCmd arguments : $commandToLog  $additionalArguments"
        Invoke-Expression "Invoke-SqlCmd @arguments $additionalArguments"

    } # End of Try
    Finally
    {
        # Cleanup the temp file & dont error out in case Deletion fails
        if ($taskType -eq "sqlInline" -and $sqlFile -and ((Test-Path $sqlFile) -eq $true))
        {
            Write-Verbose "Removing File $sqlFile"
            Remove-Item $sqlFile -ErrorAction 'SilentlyContinue'
        }
    }
}

function EscapeSpecialChars
{
    param(
        [string]$str
    )

    return $str.Replace('`', '``').Replace('$', '`$')
}