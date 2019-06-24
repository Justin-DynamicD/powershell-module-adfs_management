@{
    ModuleVersion = '1.0'
    GUID = '0ad55c54-b693-4636-9375-4877987bfdb0'
    NestedModules = @(
      '.\functions\Copy-ADFSClaimRules.ps1',
      '.\functions\Export-ADFSClaimRules.ps1',
      '.\functions\Import-ADFSClaimRules.ps1'
    )
    FunctionsToExport = @('*')
  }