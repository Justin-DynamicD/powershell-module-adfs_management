Install-WindowsFeature -Name ADFS-Federation -IncludeManagementTools
Import-Module ADFS
$serviceCreds = Get-Credential
$thumbprint = "1234567890"

###
# Install/Configure ADFS
###
$aDFSFarm = @{
    CertificateThumbprint = $thumbprint
    FederationServiceDisplayName = "Contoso Dev"
    FederationServiceName = "adfs.contoso.com"
    ServiceAccountCredential = $serviceCreds
}

Install-AdfsFarm @aDFSFarm

###
# Allow login using email address
###
$adfsClaimsProviderTrust = @{
    TargetIdentifier = "AD AUTHORITY"
    AlternateLoginID = "mail"
    LookupForests = "contoso.com"
}
Set-AdfsClaimsProviderTrust @adfsClaimsProviderTrust

###
# Update Browser List
###
Set-AdfsProperties –WIASupportedUserAgents @("MSAuthHost/1.0/In-Domain","MSIE 6.0","MSIE 7.0","MSIE 8.0","MSIE 9.0","MSIE 10.0","Trident/7.0", "MSIPC","Windows Rights Management Client","Mozilla/5.0","Edge/12")
