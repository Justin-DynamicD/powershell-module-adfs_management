# Tools-ADFS

This repo contains various scripts to aide in the deployment and configuration of ADFS.  The code has been sub-broken down into two folders.

## configuration

This folder contains the ADFSClaimRules module.  Once imported it can be used to copy claims rules for testing either locally, or to remote servers.  To import the module, simply run:

```powershell
import-module .\configuration\ADFSClaimRules.psm1
```

This module requires the `ADFS` module to be available to ensure proper operation, and will fail to run if not.  It uses the following parameters:

| Name | Req? | Type | Notes |
| ---- | ---- | ---- | ----- |
| SourceRelyingPartyTrustName | yes | string | Name of the source RPT |
| DestinationRelyingPartyTrustName | yes | string | Name of the target RPT |
| SourceADFSServer | no | string | Name of the source Server, defaults to local server |
| DestinationADFSServer | no | string | Name of the destination Server, defaults to local server |
| Credential | no | PSCredential | optional set of credentials to pass when attempting to connect to remote ADFS server.

Note that settings updates can only occur on primary servers of a given farm.  Therefore, the below example can be used to copy settings from the adfs.wedgewood-inc.com adfs-dev.wedgewood-inc.com:

```powershell
$mycreds = get-credential
Copy-ADFSClaimRules QA QA -SourceADFSServer wecadfs01 -DestinationADFSServer devadfs01 -Credential $mycreds
```

Note: If `credential` isn't specified, the local credentials are used to perform all actions.  Also note, Kerberos/Basic authentication do not allow "double hopping" credentials.  FOr example if you use `enter-pssession` to remote onto a box, the used credentials will fail if you attempt to connect to _another_ server using this script without specifying the credentials.

## installation

The installation folder contains simple scripts for instaling ADFS onto a server, as well as the WAProxy.  These commands can be used to quickly get a server up and running instead of using the gui if desired.
