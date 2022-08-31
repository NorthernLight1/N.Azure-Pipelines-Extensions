function Import-PSModule
{
	param
	(
		[string]$name
	)

	$modulePath = Resolve-Path ".\ps_modules\$name"
	
	if(Test-Path "$modulePath")
	{
		Write-Verbose "Importing '$name' module from ps_modules directory"
		Import-Module "$modulePath" -ErrorAction 'SilentlyContinue' | out-null
	}
	else
	{
		push-location
		Import-Module $name -ErrorAction 'SilentlyContinue' | out-null
		pop-location
	}
}

function Invoke-PSCommand {
	param (
		[string]$name,
		[ScriptBlock]$scriptBlock,
		[Object[]]$argumentList,
		[int]$throttleLimit,
		[switch]$asJob,
		[switch]$wait
	)
	
	$initializationScript = {
		$modulePath = Resolve-Path ".\ps_modules\N.TaskModule.SqlUtility"
		Import-Module $modulePath -Verbose #-ErrorAction 'SilentlyContinue' | out-null
	};
	
	if($asThreadJob)
	{
		Import-PSModule ThreadJob
		Start-ThreadJob -Name $name -InitializationScript $initializationScript -ScriptBlock $scriptBlock -ArgumentList $argumentList -throttleLimit $throttleLimit | out-null
		$global:jobQueuedCount++;
		Write-Output ("{0} Queued:{1}" -f $name, $global:jobQueuedCount)
		if($wait)
		{
			Wait-ThreadJobs
		}
	}
	else
	{
		Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $argumentList
	}
}

function Wait-ThreadJobs
{
	#[int]$test=(Get-Job).Count
	while((Get-Job).Count -gt 0)
	{
		$jobs = Get-Job
		
		$job = $jobs | Wait-Job -Any -Timeout 10
		if($job -ne $null)
		{
			$output = Receive-Job $job -AutoRemoveJob -Wait
			if($job.State -eq "Failed")
			{
				Write-Error ("{0} Failed!" -f $job.Name)
				$global:jobFailedCount++;
				Write-Output $output
			} 
			elseif($job.State -eq "Completed")
			{
				Write-Output ("{0} Completed" -f $job.Name)
				$global:jobCompletedCount++;
			}

		}
		$runningJobCount = ($jobs | Where-Object { $_.State -eq "Running" }).Count
		$progress = ($global:jobCompletedCount+$global:jobFailedCount)/$global:jobQueuedCount
		Write-Output ("SqlDeployment Status (Running: {1}, Failed: {2}, Completed: {3}/{4})...[{0:P}]" -f $progress, $runningJobCount, $global:jobFailedCount,$global:jobCompletedCount, $global:jobQueuedCount)
	}
}

[int]$global:jobQueuedCount = 0;
[int]$global:jobCompletedCount = 0;
[int]$global:jobFailedCount=0;