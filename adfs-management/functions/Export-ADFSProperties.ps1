function Export-ADFSProperties
{
  <#
  .SYNOPSIS
    This script exports ADFSProperties values with extra authentication rules to allow for remote execution.

  .DESCRIPTION
    Exports all global properties from farm, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.

  .EXAMPLE
    Export-ADFSProperties

    This will export all global properties in json format for saving in a config-as-code scenario.

  .EXAMPLE
    Export-ADFSProperties -Name MyClient -Server ADFS01 -Credential $creds

    In this example a remote server and credentials are proivided.  The credential parameter is not mandetory if current logged-in credentails will work.
  #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [string] $Server = $env:COMPUTERNAME,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential] $Credential
    )

    Begin
    {
        $ErrorActionPreference = "Stop"
        $params = @{
          Method = "open"
          Server = $Server
        }
        If ($Credential) { $params.Credential = $Credential }
        $sessioninfo = sessionconfig @params
    }

    Process
    {

        # gather info using existing cmdlets
        if ($sessioninfo.SourceRemote){
            $SourceProperties = Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock { Get-AdfsProperties }
        }
        else {
            $SourceProperties = Get-AdfsProperties
        }

        # convert cutomobject(s) to a hashtable so it can be easily modified for IAC tasks
        If ($SourceProperties) {
          $returnProperties = @{}
          $SourceProperties.psobject.properties | ForEach-Object { 

            # some parameters are not simple strings and need conversion
            # Others are informational only and should be trimmed
            # Do that work here.
            $tmpName = $_.Name
            $tmpValue = $_.Value
            switch ($tmpName) {
              ExtranetObservationWindow {
                # trim timespan object down to relevent data only
                $timeSpanObject = New-Object -TypeName PSObject -Property @{
                  Days = $tmpValue.Days
                  Hours = $tmpValue.Hours
                  Minutes = $tmpValue.Minutes
                  Seconds = $tmpValue.Seconds
                }
                $returnProperties[$tmpName] = $timeSpanObject
              }
              PersistentSsoCutoffTime { $importSplat[$tmpName] = $tmpValue.Date }
              default { $returnProperties[$tmpName] = $tmpValue }
            }
          }

          #remove psremote info if present
          $returnProperties.Remove("PSComputerName")
          $returnProperties.Remove("PSShowComputerName")
          $returnProperties.Remove("RunspaceId")

          # convert the whole thing down to JSON
          $returnProperties = $returnProperties | ConvertTo-Json
        }
        Else {
          Write-Warning "query returned empty, please verify parameters."
        }
    }

    End
    {
      #tear down sessions
      sessionconfig -Method close -SessionInfo $sessioninfo

      return $returnProperties
    }
}