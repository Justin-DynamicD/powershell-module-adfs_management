function Import-ADFSProperties {
  <#
  .SYNOPSIS
    This script imports ADFSProperties values with extra authentication rules to allow for remote execution.

  .DESCRIPTION
    Imports all global properties to farm, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.

  .EXAMPLE
    Import-ADFSProperties

    This will import all global properties from json format for saving in a config-as-code scenario.

  .EXAMPLE
    Import-ADFSProperties -Name MyClient -Server ADFS01 -Credential $creds

    In this example a remote server and credentials are proivided.  The credential parameter is not mandetory if current logged-in credentails will work.
  #>

  [CmdletBinding()]
  Param
  (

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [Alias("Content", "Properties")]
    [string] $ADFSContent,

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [string] $Server = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [System.Management.Automation.PSCredential] $Credential
  )

  Begin {
    $ErrorActionPreference = "Stop"

    # Validate $ADFSContent is in JSON format
    Try {
      Write-Verbose "importing JSON..."
      $ConvertedContent = ConvertFrom-Json $ADFSContent
    }
    Catch {
      Write-Error "Content was not supplied as valid JSON, aborting" -ErrorAction Stop
    }

    # login to remote server if nessisary
    $params = @{
      Method = "open"
      Server = $Server
    }
    If ($Credential) { $params.Credential = $Credential }
    $sessioninfo = sessionconfig @params
  }

  Process {

    # convert custom objects back into native types if present
    Write-Verbose "translating TimeSpans..."
    If ($null -ne $ConvertedContent.ExtranetObservationWindow) {
      $splat = @{}
      $ConvertedContent.ExtranetObservationWindow.psobject.properties | ForEach-Object {
        $splat[$_.Name] = $_.Value 
      }
      $ConvertedContent.ExtranetObservationWindow = New-TimeSpan @splat
    }

    Write-Verbose "translating DateTime..."
    If ($null -ne $ConvertedContent.PersistentSsoCutoffTime) { 
      $ConvertedContent.PersistentSsoCutoffTime = Get-Date -Date $ConvertedContent.PersistentSsoCutoffTime
    }

    Write-Verbose "translating Organization..."
    If ($null -ne $ConvertedContent.OrganizationInfo) {
      $splat = @{}
      $ConvertedContent.OrganizationInfo.psobject.properties | ForEach-Object {
        If ($null -ne $_Value) {
          $splat[$_.Name] = $_.Value
        }
      }
      $ConvertedContent.OrganizationInfo = New-AdfsOrganization @splat
    }

    Write-Verbose "translating ContactPerson..."
    If ($null -ne $ConvertedContent.ContactPerson) {
      $splat = @{}
      $ConvertedContent.ContactPerson.psobject.properties | ForEach-Object {
        If ($null -ne $_Value) {
          $splat[$_.Name] = $_.Value
        }
      }
      $ConvertedContent.ContactPerson = New-AdfsContactPerson @splat
    }

    # Some attributes have parameter naming discrepencies.
    # Do that work here.
    $importSplat = @{}
    $ConvertedContent.psobject.properties | ForEach-Object {     
      $tmpName = $_.Name
      $tmpValue = $_.Value
      switch ($tmpName) {
        CertificateSharingContainer {} # has no equivelent import value
        ExtranetLockoutEnabled { $importSplat.EnableExtranetLockout = $tmpValue }
        KmsiEnabled { $importSplat.EnableKmsi = $tmpValue }
        LoopDetectionEnabled {$importSplat.EnableLoopDetection = $tmpValue }
        PersistentSsoEnabled {$importSplat.EnablePersistentSso = $tmpValue }
        InstalledLanguage {} # has no equivelent import value
        PasswordValidationDelayInMinutes {} # has no equivelent import value
        default { $importSplat[$tmpName] = $tmpValue }
      }
    }

    # apply settings
    Write-Verbose "applying configuration..."
    if ($sessioninfo.SourceRemote) {
      $command = { Set-AdfsProperties @Using:importSplat }
      Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
    }
    else {
      Set-AdfsProperties @importSplat
    } # false

  }

  End {
    #tear down sessions
    sessionconfig -Method close -SessionInfo $sessioninfo
  }
}