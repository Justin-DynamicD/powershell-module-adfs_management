﻿<#
.Synopsis
   Copies all claim rules from one RPT to another, even on another server
.DESCRIPTION
   Inspired by original work here: https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc
   Copies all claim rules from one RPT to another, even on another server
.EXAMPLE
   Copy-ADFSClaimRules -SourceRelyingPartyTrustName "myrule" -DestinationRelyingPartyTrustName "myrule" -SourceADFSServer server01 -DestinationADFSServer server02
#>
function Copy-ADFSClaimRules
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$false,
                   Position=0)]
        [string] $SourceRelyingPartyTrustName,

        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$false,
                   Position=1)]
        [string] $DestinationRelyingPartyTrustName,

        [Parameter(Mandatory=$false,
                   ValueFromPipeline=$false)]
        [string] $SourceADFSServer = $env:COMPUTERNAME,

        [Parameter(Mandatory=$false,
                   ValueFromPipeline=$false)]
        [string] $DestinationADFSServer = $env:COMPUTERNAME
    )

    Begin
    {
        # quick query to determine if a remote connection for any configuration

        if($SourceADFSServer -ne $env:COMPUTERNAME) { $SourceRemote = $true }
        else { $SourceRemote = $false }

        if($DestinationADFSServer -ne $env:COMPUTERNAME) { $TargetRemote = $true }
        else { $TargetRemote = $false }

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
            $SourceRPT = Invoke-Command -ComputerName $SourceADFSServer -ScriptBlock $command 
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
            $DestinationRPT = Invoke-Command -ComputerName $DestinationADFSServer -ScriptBlock $command  
        }
        else {
            $DestinationRPT = Get-AdfsRelyingPartyTrust -Name $DestinationRelyingPartyTrustName
        }

        # Checks are done, do the work
        if(!$DestinationRPT) {
            Write-Output "Destination RPT does not exist, creating..."
            if ($TargetRemote){
                $command = { Add-AdfsRelyingPartyTrust -Name $Using:DestinationRelyingPartyTrustName -Identifier $Using:SourceRPT.Identifier }
                Invoke-Command -ComputerName $DestinationADFSServer -ScriptBlock $command
                $command = { Get-AdfsRelyingPartyTrust -Name $Using:DestinationRelyingPartyTrustName }
                $DestinationRPT = Invoke-Command -ComputerName $DestinationADFSServer -ScriptBlock $command
            }
            else {
                Add-AdfsRelyingPartyTrust -Name $DestinationRelyingPartyTrustName -Identifier $SourceRPT.Identifier
                $DestinationRPT = Get-AdfsRelyingPartyTrust -Name $DestinationRelyingPartyTrustName
            }
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
            Invoke-Command -ComputerName $DestinationADFSServer -ScriptBlock $command  
        }
        else {
            Set-AdfsRelyingPartyTrust @RPTSplat
        }
    
    }
    End
    {
    }
}