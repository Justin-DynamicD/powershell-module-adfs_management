@{
    ModuleVersion = '1.0'
    GUID = '0ad55c54-b693-4636-9375-4877987bfdb0'
    Author = 'Justin King'
    CompanyName = 'Unknown'
    Copyright = 'GNU General Public License v3.0'
    Description = 'Contains functions that help export and import settings in ADFS.  Helps with IaC scenarios.'
    PowerShellVersion = '4.0'
    NestedModules = @(
      '.\functions\Copy-ADFSClaimRules.ps1',
      '.\functions\Export-ADFSClaimRules.ps1',
      '.\functions\Import-ADFSClaimRules.ps1'
    )
    FunctionsToExport = @('*')
    PrivateData = @{
      PSData = @{
        Tags = @('ADFS','ConfigurationData', 'ConfigurationManagement')
        ProjectUri = 'https://github.com/Justin-DynamicD/powershell-module-adfs_management'
        LicenseUri = 'https://github.com/Justin-DynamicD/powershell-module-adfs_management/blob/master/LICENSE'
      } # End of PSData hashtable
    } # End of PrivateData hashtable
  }