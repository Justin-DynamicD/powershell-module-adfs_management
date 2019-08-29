<#
.Synopsis
   This script imports ADFSClient values with extra authentication rules to allow for remote execution.
.DESCRIPTION
   Inspired by original work here: https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc

   Imports all client rules from farm, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.
.EXAMPLE
   Import-ADFSClient $myClient

   This will import a previously exported client.
.EXAMPLE
   Get-Content .\myRPT.json | ConvertFrom-Json | Import-ADFSClient $_ -Server ADFS01 -Credential $mycreds

   In this example a json file is imported and applied to a remote server with specific credentials.
#>

function Import-ADFSClient
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true, Position=0)]
        [Alias("Content")]
        [System.Object] $ADFSClient,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [string] $Server = $env:COMPUTERNAME,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential] $Credential
    )

    Begin
    {
        $ErrorActionPreference = "Stop"

        # create an empty hashtable and populate connection info
        $pssession = @{}
        if ($Credential) {
            $pssession.Credential = $Credential
        }

        if($Server -ne $env:COMPUTERNAME) {
            $SourceRemote = $true
            $pssession.ComputerName = $Server
            $SourceSession = New-PSSession @pssession
        }
        else { $SourceRemote = $false }
    }
    Process
    {

      Write-Output "importing content"
      if ($SourceRemote){
          $command = { Set-AdfsClient @Using:RPTSplat }
          Invoke-Command -Session $SourceSession -ScriptBlock $command
      }
      else {
          Set-AdfsClient @RPTSplat
      }

    }

    End
    {
      #tear down sessions
      if ($SourceRemote) {
        Remove-PSSession -Session $SourceSession
      }

      return $returnClient
    }
}