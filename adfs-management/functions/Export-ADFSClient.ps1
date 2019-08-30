<#
.Synopsis
   This script exports ADFSClient values with extra authentication rules to allow for remote execution.
.DESCRIPTION
   Inspired by original work here: https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc

   Exports all client rules from farm, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.
.EXAMPLE
   Export-ADFSClient

   This will export all clients in json format for saving in a config-as-code scenario.
.EXAMPLE
   Export-ADFSClient -Name MyClient -Server ADFS01 -Credential $creds

   In this example a remote server and credentials are proivided.  The credential parameter is not mandetory if current logged-in credentails will work.
#>


function Export-ADFSClient
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true, Position=0)]
        [string] $Name,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string] $ClientId,

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

        # Establish Source connections  
        if($Server -ne $env:COMPUTERNAME) {
            $SourceRemote = $true
            $pssession.ComputerName = $Server
            $SourceSession = New-PSSession @pssession
        }
        else { $SourceRemote = $false }
    }
    Process
    {

        # Create Hashtable with search variables
        $clientSearch = @{}
        if ($Name) {
          $clientSearch.Name = $Name
        }
        if ($ClientId) {
          $clientSearch.ClientId = $ClientId
        }

        # gather info using existing cmdlets
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
            $clientHash.Remove("PSComputerName")
            $clientHash.Remove("PSShowComputerName")
            $clientHash.Remove("RunspaceId")
            $returnClient += $clientHash
          }
          $returnClient = $returnClient | ConvertTo-Json
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