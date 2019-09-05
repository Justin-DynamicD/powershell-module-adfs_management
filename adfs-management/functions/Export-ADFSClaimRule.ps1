function Export-ADFSClaimRule
{
  <#
  .SYNOPSIS
    This script exports RelyingPartTrust valuewith extra authentication rules to allow for remote execution.
  
  .DESCRIPTION
    Inspired by original work here: https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc

    Exports all claim rules from Relying Party Trust, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.

  .EXAMPLE
    Export-ADFSClaimRule ProdRule

    This will export a rule in json format for saving in a config-as-code scenario.

  .EXAMPLE
    Export-ADFSClaimRule -Server ADFS01 -Credential $creds

    In this example a remote server and credentials are proivided.  The credential parameter is not mandetory if current logged-in credentails will work.  The cmdlet will export every discovered trust.
  #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true, Position=0)]
        [Alias("RPT","RelyingPartyTrustName")]
        [string] $Name,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string] $Identifier,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string] $PrefixIdentifier,

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
        
        # Create Hashtable with search variables
        $claimSearch = @{}
        if ($Name) {
          $claimSearch.Name = $Name
        }
        if ($Identifier) {
          $claimSearch.Identifier = $Identifier
        }
        if ($PrefixIdentifier) {
          $claimSearch.PrefixIdentifier = $PrefixIdentifier
        }

        # gather info using existing cmdlets
        if ($sessioninfo.SourceRemote){
            $command = { Get-AdfsRelyingPartyTrust @Using:claimSearch }
            $sourceRPT = Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
        }
        else {
            $sourceRPT = Get-AdfsRelyingPartyTrust @claimSearch
        }

        # convert cutomobject to a hashtable so it can be easily modified for IAC tasks
        if($sourceRPT) {
          $returnRPT = @()
          foreach ($rPT in $sourceRPT) {
            $rPTHash = @{}
            $rPT.psobject.Properties | ForEach-Object {
              
              #certain fields are custom objects and must be exported as string to ensure they import properly
              $tmpName = $_.Name
              $tmpValue = $_.Value
              switch ($tmpName) {
                EncryptionCertificateRevocationCheck { $rPTHash[$tmpName] = "$($rPT.EncryptionCertificateRevocationCheck)" }
                SigningCertificateRevocationCheck { $rPTHash[$tmpName] = "$($rPT.SigningCertificateRevocationCheck)" }
                default { $rPTHash[$tmpName] = $tmpValue }
              }
            }

            #remove psremote info if present
            $rPTHash.Remove("PSComputerName")
            $rPTHash.Remove("PSShowComputerName")
            $rPTHash.Remove("RunspaceId")

            # Add the Hash 
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
      sessionconfig -Method close -SessionInfo $sessioninfo

      return $returnRPT
    }
}