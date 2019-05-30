#Requires -Modules ADFS
#Requires -RunAsAdministrator
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
#>
$ErrorActionPreference = "Stop"
function Copy-ADFSClaimRules
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true, ValueFromPipeline=$false, Position=0)]
        [string] $SourceRelyingPartyTrustName,

        [Parameter(Mandatory=$true, ValueFromPipeline=$false, Position=1)]
        [string] $DestinationRelyingPartyTrustName,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [string] $SourceADFSServer = $env:COMPUTERNAME,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [string] $DestinationADFSServer = $env:COMPUTERNAME,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [securestring] $Credential
    )

    Begin
    {
        # create any required sessions for connection
        if ($Credential) {
            $psrcreds = @{ Credential = $Credential }
        }

        if($SourceADFSServer -ne $env:COMPUTERNAME) { 
            $SourceRemote = $true
            $SourceSession = New-PSSession -ComputerName $SourceADFSServer @psrcreds
        }
        else { $SourceRemote = $false }

        if($DestinationADFSServer -ne $env:COMPUTERNAME) { 
            $TargetRemote = $true
            $TargetSession = New-PSSession -ComputerName $DestinationADFSServer @psrcreds
        }
        else { $TargetRemote = $false }

        # quick safety check to prevent attempting to duplicate rules on a server
        If ($SourceADFSServer -eq $DestinationADFSServer) { $CreateRPT = $false }
        else { $CreateRPT = $true }

        If (($SourceADFSServer -eq $DestinationADFSServer) -and ($SourceRelyingPartyTrustName -eq $DestinationRelyingPartyTrustName)) {
            Write-Error "Attempting to write to istelf, aborting"
            return;
        }

    }
    Process
    {

        # Establish Source connections
        if ($SourceRemote){
            $command = { Get-AdfsRelyingPartyTrust -Name $Using:SourceRelyingPartyTrustName }
            $SourceRPT = Invoke-Command -Session $SourceSession -ScriptBlock $command 
        }
        else {
            $SourceRPT = Get-AdfsRelyingPartyTrust -Name $SourceRelyingPartyTrustName
        }

        if(!$SourceRPT) {
            Write-Error "Could not find $SourceRelyingPartyTrustName"
            return;
        }


        if ($TargetRemote){
            $command = { Get-AdfsRelyingPartyTrust -Name $Using:DestinationRelyingPartyTrustName }
            $DestinationRPT = Invoke-Command -Session $TargetSession -ScriptBlock $command  
        }
        else {
            $DestinationRPT = Get-AdfsRelyingPartyTrust -Name $DestinationRelyingPartyTrustName
        }

        # Checks are done, do the work
        if(!$DestinationRPT -and $CreateRPT) {
            Write-Output "Destination RPT does not exist, creating..."
            if ($TargetRemote){
                $command = { Add-AdfsRelyingPartyTrust -Name $Using:DestinationRelyingPartyTrustName -Identifier $Using:SourceRPT.Identifier }
                Invoke-Command -Session $TargetSession -ScriptBlock $command
                $command = { Get-AdfsRelyingPartyTrust -Name $Using:DestinationRelyingPartyTrustName }
                $DestinationRPT = Invoke-Command -Session $TargetSession -ScriptBlock $command
            }
            else {
                Add-AdfsRelyingPartyTrust -Name $DestinationRelyingPartyTrustName -Identifier $SourceRPT.Identifier
                $DestinationRPT = Get-AdfsRelyingPartyTrust -Name $DestinationRelyingPartyTrustName
            }
        }
        if(!$DestinationRPT -and !$CreateRPT) {
            Write-Error "Could not find $DestinationRelyingPartyTrustName, and unique Identifier is required so cannot create, aborting."
            return;
        }

        Write-Output "copying settings over to $DestinationRelyingPartyTrustName..."
        $RPTSplat = @{
            TargetRelyingParty = $DestinationRPT
            IssuanceTransformRules = $SourceRPT.IssuanceTransformRules
            IssuanceAuthorizationRules = $SourceRPT.IssuanceAuthorizationRules
            DelegationAuthorizationRules = $SourceRPT.DelegationAuthorizationRules
            WSFedEndpoint = $SourceRPT.WSFedEndpoint
            AdditionalWSFedEndpoint = $SourceRPT.AdditionalWSFedEndpoint
            SamlEndpoint = $SourceRPT.SamlEndpoint
            EnableJWT = $SourceRpt.EnableJWT
        }

        if ($TargetRemote){
            $command = { Set-AdfsRelyingPartyTrust @Using:RPTSplat }
            Invoke-Command -Session $TargetSession -ScriptBlock $command  
        }
        else {
            Set-AdfsRelyingPartyTrust @RPTSplat
        }
    
    }
    End
    {
        #tear down sessions
        if ($SourceRemote) {
            Remove-PSSession -Session $SourceSession
        }
        if ($TargetRemote) {
            Remove-PSSession -Session $TargetSession
        }
    }
}