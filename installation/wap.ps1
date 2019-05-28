###
# install services
###

add-windowsfeature web-application-proxy
add-windowsfeature rsat-remoteaccess -includeallsubfeature


$WAP = @{
    FederationServiceTrustCredential = "System.Management.Automation.PSCredential"
    CertificateThumbprint = ""
    FederationServiceName = ""
}

Install-WebApplicationProxy @WAP