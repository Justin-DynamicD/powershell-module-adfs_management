<#
.Synopsis
   This script exports ADFSClient values with extra authentication rules to allow for remote execution.
.DESCRIPTION
   Inspired by original work here: https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc

   Exports all client rules from farm, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.
.EXAMPLE
   Export-ADFSClient | ConvertTo-Json

   This will export all clients in json format for saving in a config-as-code scenario.
.EXAMPLE
   Export-ADFSClient -Name MyClient -Server ADFS01 -Credential $creds | ConvertTo-Json

   In this example a remote server and credentials are proivided.  The credential parameter is not mandetory if current logged-in credentails will work.
#>


function Import-ADFSClient
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true, Position=0)]
        [Alias("Content")]
        [System.Array] $ADFSClient,

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

        # Create Hashtable with dearch variables
        $clientSearch = @{}
        if ($Name) {
          $clientSearch.Name = $Name
        }
        if ($ClientId) {
          $clientSearch.ClientId = $ClientId
        }

        # Establish Source connections
        if ($SourceRemote){
            $command = { Get-AdfsClient @Using:clientSearch }
            $SourceClient = Invoke-Command -Session $SourceSession -ScriptBlock $command
        }
        else {
            $SourceClient = Get-AdfsClient @clientSearch
        }

        # convert cutomobject(s) to a hashtable so it can be easily modified for IAC tasks
        If ($SourceClient) {
          $returnClient = @()
          foreach ($client in $sourceClient) {
            $clientHash = @{}
            $client.psobject.properties | ForEach-Object { $clientHash[$_.Name] = $_.Value }
            $returnClient += $clientHash
          }
        }
        Else {
          Write-Warning "Could not find any ADFS Clients"
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