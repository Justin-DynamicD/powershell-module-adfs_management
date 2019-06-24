#Requires -Modules ADFS
<#
.Synopsis
   This script exports RelyingPartTrust valuewith extra authentication rules to allow for remote execution.
.DESCRIPTION
   Inspired by original work here: https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc

   Exports all claim rules from Relying Party Trust, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.
.EXAMPLE
   Export-ADFSClaimRules ProdRule | ConvertTo-Json

   This will export a rule in json format for saving in a config-as-code scenario.
.EXAMPLE
   Export-ADFSClaimRules ProdRule -Server ADFS01 -Credential $creds | ConvertTo-Json

   In this example a remote server and credentials are proivided.  The credential parameter is not mandetory if current logged-in credentails will work.
#>
$ErrorActionPreference = "Stop"
function Export-ADFSClaimRules
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true, ValueFromPipeline=$false, Position=0)]
        [Alias("RPT")]
        [string] $RelyingPartyTrustName,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [string] $Server = $env:COMPUTERNAME,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential] $Credential
    )

    Begin
    {
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

        # Establish Source connections
        if ($SourceRemote){
            $command = { Get-AdfsRelyingPartyTrust -Name $Using:RelyingPartyTrustName }
            $SourceRPT = Invoke-Command -Session $SourceSession -ScriptBlock $command
        }
        else {
            $SourceRPT = Get-AdfsRelyingPartyTrust -Name $RelyingPartyTrustName
        }

        # convert cutomobject to a hashtable so it can be easily modified for IAC tasks
        if($SourceRPT) {
          $returnRPT = @{}
          $SourceRPT.psobject.properties | ForEach-Object { $returnRPT[$_.Name] = $_.Value }
        }
        Else {
          Write-Warning "Could not find $RelyingPartyTrustName"
        }

    }

    End
    {
      #tear down sessions
      if ($SourceRemote) {
        Remove-PSSession -Session $SourceSession
      }

      return $returnRPT
    }
}