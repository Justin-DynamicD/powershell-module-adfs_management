@{
    ModuleVersion = '1.1.0'
    GUID = '0ad55c54-b693-4636-9375-4877987bfdb0'
    Author = 'Justin King'
    CompanyName = 'Unknown'
    Copyright = 'GNU General Public License v3.0'
    Description = 'Contains functions that help export and import settings in ADFS.  Helps with IaC scenarios.'
    PowerShellVersion = '4.0'
    NestedModules = @(
      '.\functions\Copy-ADFSClaimRule.ps1',
      '.\functions\Export-ADFSClaimRule.ps1',
      '.\functions\Export-ADFSClient.ps1',
      '.\functions\Import-ADFSClaimRule.ps1',
      '.\functions\Import-ADFSClient.ps1',
      '.\functions\set-sessioncontext.ps1'
    )
    FunctionsToExport = @(
      'Copy-ADFSClaimRule',
      'Export-ADFSClaimRule',
      'Export-ADFSClient',
      'Import-ADFSClaimRule',
      'Import-ADFSClient'
    )
    PrivateData = @{
      PSData = @{
        Tags = @('ADFS','ConfigurationData', 'ConfigurationManagement')
        ProjectUri = 'https://github.com/Justin-DynamicD/powershell-module-adfs_management'
        LicenseUri = 'https://github.com/Justin-DynamicD/powershell-module-adfs_management/blob/master/LICENSE'
      } # End of PSData hashtable
    } # End of PrivateData hashtable
  }