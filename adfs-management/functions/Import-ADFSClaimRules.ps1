#Requires -Modules ADFS
<#
.Synopsis
   This script imports RelyingPartTrust valuewith extra authentication rules to allow for remote execution.
.DESCRIPTION
   Inspired by original work here: https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc

   Imports all claim rules from Relying Party Trust, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.
   If a Claims rule is missing, it is created.
.EXAMPLE
   Import-ADFSClaimRules $myRPT

   This will import a previously exported RPT rule.
.EXAMPLE
   Get-Content .\myRPT.json | ConvertFrom-Json | Import-ADFSClaimRules $_ -Server ADFS01 -Credential $mycreds

   In this example a json file is imported and applied to a remote server with specific credentials.
#>
$ErrorActionPreference = "Stop"
function Import-ADFSClaimRules
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true, ValueFromPipeline=$false, Position=0)]
        [Alias("Content")]
        [System.Object]$RelyingPartyTrustContent,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [string]$Server = $env:COMPUTERNAME,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential
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
            $command = { Get-AdfsRelyingPartyTrust -Name $Using:RelyingPartyTrustContent.Name }
            $SourceRPT = Invoke-Command -Session $SourceSession -ScriptBlock $command 
        }
        else {
            $SourceRPT = Get-AdfsRelyingPartyTrust -Name $RelyingPartyTrustContent.Name
        }

        # If the target RPT is missing, add it
        if(!$SourceRPT) {
            Write-Output "RPT does not exist, creating..."
            if ($SourceRemote){
                $command = { Add-AdfsRelyingPartyTrust -Name $Using:RelyingPartyTrustContent.Name -Identifier $Using:RelyingPartyTrustContent.Identifier }
                Invoke-Command -Session $SourceSession -ScriptBlock $command
                $SourceRPT = Get-AdfsRelyingPartyTrust -Name $RelyingPartyTrustContent.Name
            }
            else {
                Add-AdfsRelyingPartyTrust -Name $RelyingPartyTrustContent.Name -Identifier $RelyingPartyTrustContent.Identifier
                $SourceRPT = Get-AdfsRelyingPartyTrust -Name $RelyingPartyTrustContent.Name
            }
        }

        # Not every field is supported by set-AdfsRelyingPartyTrust, so we filter
        $RPTSplat = @{
            AdditionalAuthenticationRules = $RelyingPartyTrustContent.AdditionalAuthenticationRules
            AdditionalWSFedEndpoint = $RelyingPartyTrustContent.AdditionalWSFedEndpoint
            AllowedAuthenticationClassReferences = $RelyingPartyTrustContent.AllowedAuthenticationClassReferences
            AllowedClientTypes = $RelyingPartyTrustContent.AllowedClientTypes
            AlwaysRequireAuthentication = $RelyingPartyTrustContent.AlwaysRequireAuthentication
            AutoUpdateEnabled = $RelyingPartyTrustContent.AutoUpdateEnabled
            ClaimsAccepted = $RelyingPartyTrustContent.ClaimsAccepted
            ClaimsProviderName = $RelyingPartyTrustContent.ClaimsProviderName
            DelegationAuthorizationRules = $RelyingPartyTrustContent.DelegationAuthorizationRules
            EnableJWT = $RelyingPartyTrustContent.EnableJWT
            EncryptClaims = $RelyingPartyTrustContent.EncryptClaims
            EncryptedNameIdRequired = $RelyingPartyTrustContent.EncryptedNameIdRequired
            EncryptionCertificate = $RelyingPartyTrustContent.EncryptionCertificate
            EncryptionCertificateRevocationCheck  = $RelyingPartyTrustContent.EncryptionCertificateRevocationCheck
            ImpersonationAuthorizationRules = $RelyingPartyTrustContent.
            IssuanceAuthorizationRules = $RelyingPartyTrustContent.IssuanceAuthorizationRules       
            IssuanceTransformRules = $RelyingPartyTrustContent.IssuanceTransformRules
            IssueOAuthRefreshTokensTo  = $RelyingPartyTrustContent.IssueOAuthRefreshTokensTo
            MetadataUrl  = $RelyingPartyTrustContent.MetadataUrl
            MonitoringEnabled = $RelyingPartyTrustContent.MonitoringEnabled
            NotBeforeSkew = $RelyingPartyTrustContent.NotBeforeSkew
            Notes = $RelyingPartyTrustContent.Notes
            ProtocolProfile = $RelyingPartyTrustContent.ProtocolProfile
            RequestSigningCertificate = $RelyingPartyTrustContent.RequestSigningCertificate
            SamlEndpoint = $RelyingPartyTrustContent.SamlEndpoint
            SamlResponseSignature = $RelyingPartyTrustContent.SamlResponseSignature
            SignatureAlgorithm = $RelyingPartyTrustContent.SignatureAlgorithm
            SignedSamlRequestsRequired = $RelyingPartyTrustContent.SignedSamlRequestsRequired
            SigningCertificateRevocationCheck = $RelyingPartyTrustContent.SigningCertificateRevocationCheck
            TargetRelyingParty = $SourceRPT
            TokenLifetime = $RelyingPartyTrustContent.TokenLifetime
            WSFedEndpoint = $RelyingPartyTrustContent.WSFedEndpoint
        }

        Write-Output "importing content"
        if ($SourceRemote){
            $command = { Set-AdfsRelyingPartyTrust @Using:RPTSplat }
            Invoke-Command -Session $SourceSession -ScriptBlock $command  
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
    }
}