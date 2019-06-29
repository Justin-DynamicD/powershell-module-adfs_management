# adfs-management

[![Build Status](https://dev.azure.com/Justin-DynamicD/GitHubPipelines/_apis/build/status/Justin-DynamicD.powershell-module-adfs_management?branchName=master)](https://dev.azure.com/Justin-DynamicD/GitHubPipelines/_build/latest?definitionId=4&branchName=master)

This PowerShell module allows for the easy export and import of various claims and other adfs components to make it easier to control ADFS via code.  It is deliberately NOT in DSC format as those modules interact very poorly with CAPS, and a simple `import-module` ends up being faster/more reliable.

## configuration

To import the module while editing, simply run:

```powershell
import-module .\adfs-management
```

This module requires the `ADFS` module to be available to ensure proper operation, but _will_ import without the module being installed incase the user plans to connect remotely.

Note that settings updates can only occur on primary servers of a given ADFS farm.  Therefore, the below example can be used to copy settings from the one adfs server to another:

```powershell
$mycreds = get-credential
Copy-ADFSClaimRules somerule somerule -SourceADFSServer server01 -DestinationADFSServer server02 -Credential $mycreds
```

Note: If `credential` isn't specified, the local credentials are used to perform all actions.  Also note, Kerberos/Basic authentication do not allow "double hopping" credentials.  For example if you use `enter-pssession` to remote onto a box, the used credentials will fail if you attempt to connect to _another_ server using this script without specifying the credentials.
