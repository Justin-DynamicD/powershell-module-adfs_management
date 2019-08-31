# adfs-management

[![Build Status](https://dev.azure.com/Justin-DynamicD/GitHubPipelines/_apis/build/status/Justin-DynamicD.powershell-module-adfs_management?branchName=master)](https://dev.azure.com/Justin-DynamicD/GitHubPipelines/_build/latest?definitionId=4&branchName=master)

Inspired by original work here: <https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc>

TLDR: This PowerShell module allows for export and import of various claims and other ADFS components to make it easier to control ADFS via code.  It is deliberately NOT in DSC format as those modules interact very poorly with CAPS, and instead aims to be a simple 1-line command that returns/updates data in a universally understandable format (JSON).

Working at clients that have established DTAP environments, replicating client and claim rules across environments has proven to be error prone.  This module is an attempt to streamline that process.  By wrapping some of the common ADFS cmdlets in `export`, `import`, and `copy` modules, this adds the following functionality:

- import/export accept/return json string. This makes it easier to pipe in configuration declarations, especially with non-Windows Config Management systems
- `-credential` and `-server` parameters were added to allow remote execution
- custom `destroy` attributes were added to allow removal of rules and clients

It should be reiterated that these are cmdlets, not idempotent DSC modules, therefore it does not modify/remove anything undefined.  This makes it a simple/common tool for sharing/syncing configuration snippets as opposed to wholistic config management. That said, it can be leveraged/wrapped by a CAPS system easily as everything can be run as a local exec command and the return is a predictable JSON which all CAPS systems can easily import.

## configuration

To import the module while editing, simply run:

```powershell
import-module .\adfs-management
```

This module requires the `ADFS` module to be available to ensure proper operation, but _will_ import without the module being installed incase the user plans to connect remotely (Only target servers need the tools installed, in this case)

## examples

Remember that settings updates can only occur on primary servers of a given ADFS farm. The below example can be used to export ADFS claims rules from a remote server:

```powershell
$mycreds = get-credential
Export-ADFSClaimRule somerule -Server server01 -Credential $mycreds
```

Note: If `credential` isn't specified, the local credentials are used to perform all actions.
