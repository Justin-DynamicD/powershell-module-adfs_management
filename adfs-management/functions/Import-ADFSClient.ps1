<#
.Synopsis
   This script imports ADFSClient values with extra authentication rules to allow for remote execution.
.DESCRIPTION
   Inspired by original work here: https://gallery.technet.microsoft.com/scriptcenter/Copy-ADFS-claim-rules-from-3c23b4bc

   Imports all client rules from farm, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.
.EXAMPLE
   Import-ADFSClient $myClient

   This will import a previously exported client.
.EXAMPLE
   Get-Content .\myRPT.json | ConvertFrom-Json | Import-ADFSClient $_ -Server ADFS01 -Credential $mycreds

   In this example a json file is imported and applied to a remote server with specific credentials.
#>

function Import-ADFSClient {
  [CmdletBinding()]
  Param
  (
    # Param1 help description
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

    # create an empty hashtable and populate connection info
    $pssession = @{ }
    if ($Credential) {
      $pssession.Credential = $Credential
    }

    # Establish Source connections  
    if ($Server -ne $env:COMPUTERNAME) {
      $SourceRemote = $true
      $pssession.ComputerName = $Server
      $SourceSession = New-PSSession @pssession
    }
    else { $SourceRemote = $false }
  }
  Process {

    # Query existing ADFSClients
    if ($SourceRemote) {
      $sourceClient = Invoke-Command -Session $SourceSession -ScriptBlock "Get-ADFSClient"
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
        if ($SourceRemote) {
          $command = { Add-AdfsClient @Using:clientAddSplat @Using:clientCommonSplat }
          Invoke-Command -Session $SourceSession -ScriptBlock $command
        }
        else {
          Add-AdfsClient @clientAddSplat @clientCommonSplat
        }
      } # End Create

      # Update existing ClientID
      Else {
        if ($SourceRemote) {
          $command = { Set-AdfsClient @Using:clientSetSplat @Using:clientCommonSplat}
          Invoke-Command -Session $SourceSession -ScriptBlock $command
        }
        else {
          Set-AdfsClient @clientSetSplat @clientCommonSplat
        }
      } # End Update

      # Toggle Enable/Disable as needed
      switch ($adfsClient.Enabled) {
        $true {
          if ($SourceRemote) {
            $command = { Enable-AdfsClient @Using:clientSetSplat }
            Invoke-Command -Session $SourceSession -ScriptBlock $command
          }
          else {
            Enable-AdfsClient @clientSetSplat
          } # true
        }
        $false {
          if ($SourceRemote) {
            $command = { Disable-AdfsClient @Using:clientSetSplat }
            Invoke-Command -Session $SourceSession -ScriptBlock $command
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
    if ($SourceRemote) {
      Remove-PSSession -Session $SourceSession
    }
  }
}