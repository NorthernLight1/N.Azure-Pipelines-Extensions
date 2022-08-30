param([string] $baseDirectory=".",
      [string] $nugetAPIKey)

$baseDirectory = Resolve-Path $baseDirectory
$subDirectories = Get-ChildItem -Directory $baseDirectory 

foreach($directory in $subDirectories) {
 
    try{
        $directoryName = $directory.Name
        Publish-Module -Path "$baseDirectory\$directoryName\" -NuGetApiKey $nugetAPIKey -Verbose
    }
    catch{
        Write-Warning $_.Exception
    }
}
