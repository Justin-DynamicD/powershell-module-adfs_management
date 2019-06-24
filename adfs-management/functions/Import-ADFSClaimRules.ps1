#Requires -Modules ADFS
<#
.Synopsis
   This script imports RelyingPartTrust valuewith extra authentication rules to allow for remote execution.
.DESCRIPTION
   Inspired by original work here: https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc

   Imports all claim rules from Relying Party Trust, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.
   If a Claims rule is missing, it is created.

   while export-adfsclaimsrule fetches configurations "as-is" using the adfs cmdlets, the import will re-format said output to be compatible with the input format.
   For example, an export will define `ClaimsAccepted`.  This function will convert it to `ClaimAccepted` to ensure it imports.
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

        # Not every field is supported by set-AdfsRelyingPartyTrust, plus null entries are problematic, so we filter and convert as needed.
        $RPTSplat = @{}
        $RPTSplat.TargetRelyingParty = $SourceRPT
            If ($null -ne $RelyingPartyTrustContent.AdditionalAuthenticationRules) {
            $RPTSplat.AdditionalAuthenticationRules = $RelyingPartyTrustContent.AdditionalAuthenticationRules
            }
            If ($null -ne $RelyingPartyTrustContent.AdditionalWSFedEndpoint) {
                $RPTSplat.AdditionalWSFedEndpoint = $RelyingPartyTrustContent.AdditionalWSFedEndpoint
            }
            If ($null -ne $RelyingPartyTrustContent.AllowedAuthenticationClassReferences) {
                $RPTSplat.AllowedAuthenticationClassReferences = $RelyingPartyTrustContent.AllowedAuthenticationClassReferences
            }
            If ($null -ne $RelyingPartyTrustContent.AllowedClientTypes) {
                $RPTSplat.AllowedClientTypes = $RelyingPartyTrustContent.AllowedClientTypes
            }
            If ($null -ne $RelyingPartyTrustContent.AlwaysRequireAuthentication) {
                $RPTSplat.AlwaysRequireAuthentication = $RelyingPartyTrustContent.AlwaysRequireAuthentication
            }
            If ($null -ne $RelyingPartyTrustContent.AutoUpdateEnabled) {
                $RPTSplat.AutoUpdateEnabled = $RelyingPartyTrustContent.AutoUpdateEnabled
            }
            If ($null -ne $RelyingPartyTrustContent.ClaimsAccepted) {
                $RPTSplat.ClaimAccepted = $RelyingPartyTrustContent.ClaimsAccepted
            }
            If ($null -ne $RelyingPartyTrustContent.ClaimsProviderName) {
                $RPTSplat.ClaimsProviderName = $RelyingPartyTrustContent.ClaimsProviderName
            }
            If ($null -ne $RelyingPartyTrustContent.DelegationAuthorizationRules) {
                $RPTSplat.DelegationAuthorizationRules = $RelyingPartyTrustContent.DelegationAuthorizationRules
            }
            If ($null -ne $RelyingPartyTrustContent.EnableJWT) {
                $RPTSplat.EnableJWT = $RelyingPartyTrustContent.EnableJWT
            }
            If ($null -ne $RelyingPartyTrustContent.EncryptClaims) {
                $RPTSplat.EncryptClaims = $RelyingPartyTrustContent.EncryptClaims
            }
            If ($null -ne $RelyingPartyTrustContent.EncryptedNameIdRequired) {
                $RPTSplat.EncryptedNameIdRequired = $RelyingPartyTrustContent.EncryptedNameIdRequired
            }
            If ($null -ne $RelyingPartyTrustContent.EncryptionCertificate) {
                $RPTSplat.EncryptionCertificate = $RelyingPartyTrustContent.EncryptionCertificate
            }
            If ($null -ne $RelyingPartyTrustContent.EncryptionCertificateRevocationCheck) {
                $RPTSplat.EncryptionCertificateRevocationCheck  = $RelyingPartyTrustContent.EncryptionCertificateRevocationCheck
            }
            If ($null -ne $RelyingPartyTrustContent.ImpersonationAuthorizationRules) {
                $RPTSplat.ImpersonationAuthorizationRules = $RelyingPartyTrustContent.ImpersonationAuthorizationRules
            }
            If ($null -ne $RelyingPartyTrustContent.IssuanceAuthorizationRules) {
                $RPTSplat.IssuanceAuthorizationRules = $RelyingPartyTrustContent.IssuanceAuthorizationRules       
            }
            If ($null -ne $RelyingPartyTrustContent.IssuanceTransformRules) {
                $RPTSplat.IssuanceTransformRules = $RelyingPartyTrustContent.IssuanceTransformRules
            }
            If ($null -ne $RelyingPartyTrustContent.IssueOAuthRefreshTokensTo) {
                $RPTSplat.IssueOAuthRefreshTokensTo  = $RelyingPartyTrustContent.IssueOAuthRefreshTokensTo
            }
            If ($null -ne $RelyingPartyTrustContent.MetadataUrl) {
                $RPTSplat.MetadataUrl  = $RelyingPartyTrustContent.MetadataUrl
            }
            If ($null -ne $RelyingPartyTrustContent.MonitoringEnabled) {
                $RPTSplat.MonitoringEnabled = $RelyingPartyTrustContent.MonitoringEnabled
            }
            If ($null -ne $RelyingPartyTrustContent.NotBeforeSkew) {
                $RPTSplat.NotBeforeSkew = $RelyingPartyTrustContent.NotBeforeSkew
            }
            If ($null -ne $RelyingPartyTrustContent.Notes) {
                $RPTSplat.Notes = $RelyingPartyTrustContent.Notes
            }
            If ($null -ne $RelyingPartyTrustContent.ProtocolProfile) {
                $RPTSplat.ProtocolProfile = $RelyingPartyTrustContent.ProtocolProfile
            }
            If ($null -ne $RelyingPartyTrustContent.RequestSigningCertificate) {
                $RPTSplat.RequestSigningCertificate = $RelyingPartyTrustContent.RequestSigningCertificate
            }
            If ($null -ne $RelyingPartyTrustContent.SamlEndpoint) {
                $RPTSplat.SamlEndpoint = $RelyingPartyTrustContent.SamlEndpoint
            }
            If ($null -ne $RelyingPartyTrustContent.SamlResponseSignature) {
                $RPTSplat.SamlResponseSignature = $RelyingPartyTrustContent.SamlResponseSignature
            }
            If ($null -ne $RelyingPartyTrustContent.SignatureAlgorithm) {
                $RPTSplat.SignatureAlgorithm = $RelyingPartyTrustContent.SignatureAlgorithm
            }
            If ($null -ne $RelyingPartyTrustContent.SignedSamlRequestsRequired) {
                $RPTSplat.SignedSamlRequestsRequired = $RelyingPartyTrustContent.SignedSamlRequestsRequired
            }
            If ($null -ne $RelyingPartyTrustContent.SigningCertificateRevocationCheck) {
                $RPTSplat.SigningCertificateRevocationCheck = $RelyingPartyTrustContent.SigningCertificateRevocationCheck
            }
            If ($null -ne $RelyingPartyTrustContent.TokenLifetime) {
                $RPTSplat.TokenLifetime = $RelyingPartyTrustContent.TokenLifetime
            }
            If ($null -ne $RelyingPartyTrustContent.WSFedEndpoint) {
                $RPTSplat.WSFedEndpoint = $RelyingPartyTrustContent.WSFedEndpoint
            }

        # Finally work can be done.
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