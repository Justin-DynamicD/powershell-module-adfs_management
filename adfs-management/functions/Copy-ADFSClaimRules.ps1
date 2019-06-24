#Requires -Modules ADFS
<#
.Synopsis
   This script allows quick duplication of Relying Party trusts, either within or across farms.
.DESCRIPTION
   Inspired by original work here: https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc

   Copies all claim rules from one RPT to another within a farm, which is useful for testing claims in "all-in-one scenarios".  It can also duplicate rules across farms for more complete testing scenarios, allowing pulling/pushing of settings between dev/test/prod.
.EXAMPLE
   Copy-ADFSClaimRules ProdRule TestRule

   This command duplicates the settings from `ProdRule` into `TestRule`.  If `TestRule` doesn't exist, it will error as each RPT requires a unique identifier that cannot be copied.

.EXAMPLE
   Copy-ADFSClaimRules -SourceRelyingPartyTrustName QA -DestinationRelyingPartyTrustName QA -SourceADFSServer server01 -DestinationADFSServer server02

   This will copy the "QA" rule exactly between the two servers listed, creating the rule if it is missing.  Note that this command should be run on the primary server of each farm.
   Either ADFSServer value can be omitted and the local host will be the assumed machine.
.EXAMPLE
   Copy-ADFSClaimRules QA QA -SourceADFSServer server01 -DestinationADFSServer server02 -Credential $mycreds

   when running Powershell remotely, many auth methods do not allow passthrough authentication.  The `credential` param allows passing through credentials, which can be generated via `get-credential` cmdlet.
#>
$ErrorActionPreference = "Stop"
function Copy-ADFSClaimRules
{
  [CmdletBinding()]
  Param
  (
    # Param1 help description
    [Parameter(Mandatory=$true, ValueFromPipeline=$false, Position=0)]
    [Alias("SourceRPT")]
    [string] $SourceRelyingPartyTrustName,

    [Parameter(Mandatory=$true, ValueFromPipeline=$false, Position=1)]
    [Alias("TargetRPT")]
    [string] $DestinationRelyingPartyTrustName,

    [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
    [Alias("SourceServer")]
    [string] $SourceADFSServer = $env:COMPUTERNAME,

    [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
    [Alias("TargetServer")]
    [string] $DestinationADFSServer = $env:COMPUTERNAME,

    [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
    [System.Management.Automation.PSCredential] $Credential
  )

  Begin
  {
    # quick safety check to prevent attempting to duplicate rules on a server
    If (($SourceADFSServer -eq $DestinationADFSServer) -and ($SourceRelyingPartyTrustName -eq $DestinationRelyingPartyTrustName)) {
      Write-Error "Attempting to write claims to istelf, aborting" -ErrorAction Stop
    }
  }
  Process
  {
    # Export settings from Source
    $exportVars = @{
      server = $SourceADFSServer
      RelyingPartyTrustName = $SourceRelyingPartyTrustName
    }
    if ($Credential) {
      $exportVars.Credential = $Credential
    }
    Write-Output "Exporting $($SourceRelyingPartyTrustName)..."
    $capturedRPT = Export-ADFSClaimRules  @exportVars
    
    # If nothing was found, error
    If ($null -eq $capturedRPT) {
      Write-Error "RPT $SourceRelyingPartyTrustName could not be found. Aborting" -ErrorAction Stop
    }

    # If the RelyingPartyTrust Name changes, update the name
    If ($SourceRelyingPartyTrustName -ne $DestinationRelyingPartyTrustName){
      $capturedRPT.Name = $DestinationRelyingPartyTrustName
    }

    # Import settings to destination
    Write-Output "Importing $($capturedRPT.Name)..."
    $importVars = @{
    server = $DestinationADFSServer
    RelyingPartyTrustContent = $capturedRPT
    }
    if ($Credential) {
        $importVars.Credential = $Credential
    }
    Import-ADFSClaimRules @importVars

  }
  End {}
}