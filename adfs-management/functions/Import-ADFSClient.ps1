function Import-ADFSClient {
  <#
  .SYNOPSIS
    This script imports ADFSClient values with extra authentication rules to allow for remote execution.

  .DESCRIPTION
    Imports all client rules to farm, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.

  .EXAMPLE
    Import-ADFSClient

    This will import all clients from json format for saving in a config-as-code scenario.

  .EXAMPLE
    Import-ADFSClient -Name MyClient -Server ADFS01 -Credential $creds

    In this example a remote server and credentials are proivided.  The credential parameter is not mandetory if current logged-in credentails will work.
  #>

  [CmdletBinding()]
  Param
  (

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 0)]
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

    # Query existing ADFSClients
    if ($sessioninfo.SourceRemote) {
      $sourceClient = Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock "Get-ADFSClient"
    }
    else {
      $sourceClient = Get-AdfsClient
    }

    # Perform on each object entered
    Write-Output "importing content..."

    foreach ($adfsClient in $ConvertedContent) {

      # BuiltIn clients dont support updating all values.  Scan and flag
      $find = Get-AdfsClient | Where-Object { $_.ClientId -eq $adfsClient.ClientId }
      If ($find) {$builtIn = $find.BuiltIn}
      Else {$builtIn = $false}

      $clientAddSplat = @{}
      $clientSetSplat = @{}
      $clientCommonSplat = @{}
      If ($null -ne $adfsClient.RedirectUri) {
        $clientCommonSplat.RedirectUri = $adfsClient.RedirectUri
      }
      If (($null -ne $adfsClient.Name) -and !$builtIn) {
        $clientCommonSplat.Name = $adfsClient.Name
      }
      If (($null -ne $adfsClient.Description) -and !$builtIn) {
        $clientCommonSplat.Description = $adfsClient.Description
      }
      If ($null -ne $adfsClient.ClientId) {
        $clientAddSplat.ClientId = $adfsClient.ClientId
        $clientSetSplat.TargetClientId = $adfsClient.ClientId
      }
 
      # create missing ClientID
      If ($sourceClient.ClientID -notcontains $adfsClient.ClientID) {
        if ($sessioninfo.SourceRemote) {
          $command = { Add-AdfsClient @Using:clientAddSplat @Using:clientCommonSplat }
          Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
        }
        else {
          Add-AdfsClient @clientAddSplat @clientCommonSplat
        }
      } # End Create

      # Update existing ClientID
      Else {
        if ($sessioninfo.SourceRemote) {
          $command = { Set-AdfsClient @Using:clientSetSplat @Using:clientCommonSplat}
          Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
        }
        else {
          Set-AdfsClient @clientSetSplat @clientCommonSplat
        }
      } # End Update

      # Toggle Enable/Disable as needed
      switch ($adfsClient.Enabled) {
        $true {
          if ($sessioninfo.SourceRemote) {
            $command = { Enable-AdfsClient @Using:clientSetSplat }
            Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
          }
          else {
            Enable-AdfsClient @clientSetSplat
          } # true
        }
        $false {
          if ($sessioninfo.SourceRemote) {
            $command = { Disable-AdfsClient @Using:clientSetSplat }
            Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
          }
          else {
            Disable-AdfsClient @clientSetSplat
          } # false
        }
      } # End Enable Toggle
    }
  }

  End {
    #tear down sessions
    sessionconfig -Method close -SessionInfo $sessioninfo
  }
}