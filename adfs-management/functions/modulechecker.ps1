function modulechecker {

  [CmdletBinding()]
  Param
  (
    [Parameter(Mandatory = $false)]
    [hashtable] $SessionInfo = @{ SourceRemote = $false },

    [Parameter(Mandatory = $false)]
    [Array]$PSModules = @(
      @{ 
        ModuleName = "ADFS" 
        ModuleVersion = "1.0.0.0"
      }
    )
  )
  
  $ErrorActionPreference = "Stop"
  $missingModules = @()

  $PSModules | ForEach-Object {
    $currentModule = $_
    switch ($SessionInfo.SourceRemote) {
      $true {
        $command = { Get-Module -ListAvailable -FullyQualifiedName $Using:currentModule }
        $results = Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
      }
      $false {
        $results = Get-Module -ListAvailable -FullyQualifiedName $currentModule
      }
    }

    If ($null -eq $results) {
      $currentModule.Status = "Missing"
      $missingModules += $currentModule
    }
  }

  If ($missingModules -ne @()) {
    Write-Output "Summary:"
    $missingModules
    Write-Error "Required modules are missing, cannot continue." -ErrorAction Stop
  }

}