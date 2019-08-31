function Import-ADFSClaimRule {
  <#
    .SYNOPSIS
    This script imports RelyingPartTrust valuewith extra authentication rules to allow for remote execution.

    .DESCRIPTION
    Imports all claim rules from Relying Party Trust, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.
    If a Claims rule is missing, it is created.

    while export-adfsclaimsrule fetches configurations "as-is" using the adfs cmdlets, the import will re-format said output to be compatible with the input format.
    For example, an export will define `ClaimsAccepted`.  This function will convert it to `ClaimAccepted` to ensure it imports.

    .EXAMPLE
    Import-ADFSClaimRule $myRPT

    This will import a previously exported RPT rule.

    .EXAMPLE
    Get-Content .\myRPT.json | ConvertFrom-Json | Import-ADFSClaimRule $_ -Server ADFS01 -Credential $mycreds

    In this example a json file is imported and applied to a remote server with specific credentials.
    #>

  [CmdletBinding()]
  Param
  (
    # Param1 help description
    [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0)]
    [Alias("Content", "RPT")]
    [System.Object]$RelyingPartyTrustContent,

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [string]$Server = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [System.Management.Automation.PSCredential]$Credential
  )

  Begin {
    $ErrorActionPreference = "Stop"
    # Validate $ADFSContent is in JSON format
    Try {
      $convertedContent = ConvertFrom-Json $RelyingPartyTrustContent
    }
    Catch {
      Write-Error "Content was not supplied as valid JSON, aborting" -ErrorAction Stop
    }

    # create an empty hashtable and populate connection info
    $pssession = @{ }
    if ($Credential) {
      $pssession.Credential = $Credential
    }

    if ($Server -ne $env:COMPUTERNAME) {
      $SourceRemote = $true
      $pssession.ComputerName = $Server
      $SourceSession = New-PSSession @pssession
    }
    else { $SourceRemote = $false }
  }
  Process {

    foreach ($adfsRPT in $convertedContent) {
      # Query for existing trust
      if ($SourceRemote) {
        $command = { Get-AdfsRelyingPartyTrust -Name $Using:adfsRPT.Name }
        $SourceRPT = Invoke-Command -Session $SourceSession -ScriptBlock $command
      }
      else {
        $SourceRPT = Get-AdfsRelyingPartyTrust -Name $adfsRPT.Name
      }

      # If the target RPT is missing, add it
      if (!$SourceRPT) {
        Write-Output "RPT does not exist, creating..."
        if ($SourceRemote) {
          $command = { Add-AdfsRelyingPartyTrust -Name $Using:adfsRPT.Name -Identifier $Using:adfsRPT.Identifier }
          Invoke-Command -Session $SourceSession -ScriptBlock $command
          $SourceRPT = Get-AdfsRelyingPartyTrust -Name $adfsRPT.Name
        }
        else {
          Add-AdfsRelyingPartyTrust -Name $adfsRPT.Name -Identifier $adfsRPT.Identifier
          $SourceRPT = Get-AdfsRelyingPartyTrust -Name $adfsRPT.Name
        }
      }

      # Not every field is supported by set-AdfsRelyingPartyTrust, plus null entries are problematic, so we filter and convert as needed.
      $RPTSplat = @{ }
      $RPTSplat.TargetRelyingParty = $SourceRPT
      If ($null -ne $adfsRPT.AdditionalAuthenticationRules) {
        $RPTSplat.AdditionalAuthenticationRules = $adfsRPT.AdditionalAuthenticationRules
      }
      If ($null -ne $adfsRPT.AdditionalWSFedEndpoint) {
        $RPTSplat.AdditionalWSFedEndpoint = $adfsRPT.AdditionalWSFedEndpoint
      }
      If ($null -ne $adfsRPT.AllowedAuthenticationClassReferences) {
        $RPTSplat.AllowedAuthenticationClassReferences = $adfsRPT.AllowedAuthenticationClassReferences
      }
      If ($null -ne $adfsRPT.AllowedClientTypes) {
        $RPTSplat.AllowedClientTypes = $adfsRPT.AllowedClientTypes
      }
      If ($null -ne $adfsRPT.AlwaysRequireAuthentication) {
        $RPTSplat.AlwaysRequireAuthentication = $adfsRPT.AlwaysRequireAuthentication
      }
      If ($null -ne $adfsRPT.AutoUpdateEnabled) {
        $RPTSplat.AutoUpdateEnabled = $adfsRPT.AutoUpdateEnabled
      }
      If ($null -ne $adfsRPT.ClaimsAccepted) {
        $RPTSplat.ClaimAccepted = $adfsRPT.ClaimsAccepted
      }
      If ($null -ne $adfsRPT.ClaimsProviderName) {
        $RPTSplat.ClaimsProviderName = $adfsRPT.ClaimsProviderName
      }
      If ($null -ne $adfsRPT.DelegationAuthorizationRules) {
        $RPTSplat.DelegationAuthorizationRules = $adfsRPT.DelegationAuthorizationRules
      }
      If ($null -ne $adfsRPT.EnableJWT) {
        $RPTSplat.EnableJWT = $adfsRPT.EnableJWT
      }
      If ($null -ne $adfsRPT.EncryptClaims) {
        $RPTSplat.EncryptClaims = $adfsRPT.EncryptClaims
      }
      If ($null -ne $adfsRPT.EncryptedNameIdRequired) {
        $RPTSplat.EncryptedNameIdRequired = $adfsRPT.EncryptedNameIdRequired
      }
      If ($null -ne $adfsRPT.EncryptionCertificate) {
        $RPTSplat.EncryptionCertificate = $adfsRPT.EncryptionCertificate
      }
      If ($null -ne $adfsRPT.EncryptionCertificateRevocationCheck) {
        $RPTSplat.EncryptionCertificateRevocationCheck = $adfsRPT.EncryptionCertificateRevocationCheck
      }
      If ($null -ne $adfsRPT.ImpersonationAuthorizationRules) {
        $RPTSplat.ImpersonationAuthorizationRules = $adfsRPT.ImpersonationAuthorizationRules
      }
      If ($null -ne $adfsRPT.IssuanceAuthorizationRules) {
        $RPTSplat.IssuanceAuthorizationRules = $adfsRPT.IssuanceAuthorizationRules
      }
      If ($null -ne $adfsRPT.IssuanceTransformRules) {
        $RPTSplat.IssuanceTransformRules = $adfsRPT.IssuanceTransformRules
      }
      If ($null -ne $adfsRPT.IssueOAuthRefreshTokensTo) {
        $RPTSplat.IssueOAuthRefreshTokensTo = $adfsRPT.IssueOAuthRefreshTokensTo
      }
      If ($null -ne $adfsRPT.MetadataUrl) {
        $RPTSplat.MetadataUrl = $adfsRPT.MetadataUrl
      }
      If ($null -ne $adfsRPT.MonitoringEnabled) {
        $RPTSplat.MonitoringEnabled = $adfsRPT.MonitoringEnabled
      }
      If ($null -ne $adfsRPT.NotBeforeSkew) {
        $RPTSplat.NotBeforeSkew = $adfsRPT.NotBeforeSkew
      }
      If ($null -ne $adfsRPT.Notes) {
        $RPTSplat.Notes = $adfsRPT.Notes
      }
      If ($null -ne $adfsRPT.ProtocolProfile) {
        $RPTSplat.ProtocolProfile = $adfsRPT.ProtocolProfile
      }
      If ($null -ne $adfsRPT.RequestSigningCertificate) {
        $RPTSplat.RequestSigningCertificate = $adfsRPT.RequestSigningCertificate
      }
      If ($null -ne $adfsRPT.SamlEndpoint) {
        $RPTSplat.SamlEndpoint = $adfsRPT.SamlEndpoint
      }
      If ($null -ne $adfsRPT.SamlResponseSignature) {
        $RPTSplat.SamlResponseSignature = $adfsRPT.SamlResponseSignature
      }
      If ($null -ne $adfsRPT.SignatureAlgorithm) {
        $RPTSplat.SignatureAlgorithm = $adfsRPT.SignatureAlgorithm
      }
      If ($null -ne $adfsRPT.SignedSamlRequestsRequired) {
        $RPTSplat.SignedSamlRequestsRequired = $adfsRPT.SignedSamlRequestsRequired
      }
      If ($null -ne $adfsRPT.SigningCertificateRevocationCheck) {
        $RPTSplat.SigningCertificateRevocationCheck = $adfsRPT.SigningCertificateRevocationCheck
      }
      If ($null -ne $adfsRPT.TokenLifetime) {
        $RPTSplat.TokenLifetime = $adfsRPT.TokenLifetime
      }
      If ($null -ne $adfsRPT.WSFedEndpoint) {
        $RPTSplat.WSFedEndpoint = $adfsRPT.WSFedEndpoint
      }

      # Finally work can be done.
      Write-Output "importing content"
      if ($SourceRemote) {
        $command = { Set-AdfsRelyingPartyTrust @Using:RPTSplat }
        Invoke-Command -Session $SourceSession -ScriptBlock $command
      }
      else {
        Set-AdfsRelyingPartyTrust @RPTSplat
      }
    } # End RPT Loop
  }
  End {
    #tear down sessions
    if ($SourceRemote) {
      Remove-PSSession -Session $SourceSession
    }
  }
}