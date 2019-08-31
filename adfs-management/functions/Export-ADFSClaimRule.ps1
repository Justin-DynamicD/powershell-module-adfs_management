function Export-ADFSClaimRule
{
  <#
  .SYNOPSIS
    This script exports RelyingPartTrust valuewith extra authentication rules to allow for remote execution.
  
  .DESCRIPTION
    Inspired by original work here: https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc

    Exports all claim rules from Relying Party Trust, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.

  .EXAMPLE
    Export-ADFSClaimRule ProdRule | ConvertTo-Json

    This will export a rule in json format for saving in a config-as-code scenario.

  .EXAMPLE
    Export-ADFSClaimRule ProdRule -Server ADFS01 -Credential $creds | ConvertTo-Json

    In this example a remote server and credentials are proivided.  The credential parameter is not mandetory if current logged-in credentails will work.
  #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true, Position=0)]
        [Alias("RPT","RelyingPartyTrustName")]
        [string] $Name,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string] $Identifier,

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
        
        # Create Hashtable with search variables
        $claimSearch = @{}
        if ($Name) {
          $claimSearch.Name = $Name
        }
        if ($Identifier) {
          $claimSearch.Identifier = $Identifier
        }

        # gather info using existing cmdlets
        if ($SourceRemote){
            $command = { Get-AdfsRelyingPartyTrust @Using:claimSearch }
            $sourceRPT = Invoke-Command -Session $SourceSession -ScriptBlock $command
        }
        else {
            $sourceRPT = Get-AdfsRelyingPartyTrust @claimSearch
        }

        # convert cutomobject to a hashtable so it can be easily modified for IAC tasks
        if($sourceRPT) {
          $returnRPT = @()
          foreach ($rPT in $sourceRPT) {
            $rPTHash = @{}
            $rPT.psobject.properties | ForEach-Object { $rPTHash[$_.Name] = $_.Value }
            $rPTHash.Remove("PSComputerName")
            $rPTHash.Remove("PSShowComputerName")
            $rPTHash.Remove("RunspaceId")
            $returnRPT += $rPTHash
          }
          $returnRPT = $returnRPT | ConvertTo-Json
        }
        Else {
          Write-Warning "Could not find any Relying Party Trust"
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