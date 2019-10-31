function Import-ADFSClaimRule {
  <#
    .SYNOPSIS
    This script imports RelyingPartTrust valuewith extra authentication rules to allow for remote execution.

    .DESCRIPTION
    Imports all claim rules from Relying Party Trust, with extra local/remote server and credential flags to make it more flexible in a CI/CD scenario.
    If a Claims rule is missing, it is created.

    while export-adfsclaimsrule fetches configurations "as-is" using the adfs cmdlets, the import will re-format said output to be compatible with the input format.
    For example, an export will define `ClaimsAccepted`.  This function will convert it to `ClaimAccepted` to ensure it imports.

    .EXAMPLE
    Import-ADFSClaimRule $myRPT

    This will import a previously exported RPT rule.

    .EXAMPLE
    Get-Content .\myRPT.json | Import-ADFSClaimRule $_ -Server ADFS01 -Credential $mycreds

    In this example a json file is imported and applied to a remote server with specific credentials.
    #>

  [CmdletBinding()]
  Param
  (
    # Param1 help description
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [Alias("Content", "RPT")]
    [string]$RelyingPartyTrustContent,

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [string]$Server = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [System.Management.Automation.PSCredential]$Credential
  )

  Begin {
    $ErrorActionPreference = "Stop"
    # Validate $ADFSContent is in JSON format
    Try {
      $convertedContent = ConvertFrom-Json $RelyingPartyTrustContent
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
    
    # Check for required Modules
    modulechecker -SessionInfo $sessioninfo
  }

  Process {

    foreach ($adfsRPT in $convertedContent) {
      # Query for existing trust
      if ($sessioninfo.SourceRemote) {
        $command = { Get-AdfsRelyingPartyTrust -Name $Using:adfsRPT.Name }
        $SourceRPT = Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
      }
      else {
        $SourceRPT = Get-AdfsRelyingPartyTrust -Name $adfsRPT.Name
      }

      # If the target RPT is missing, add it
      if (!$SourceRPT) {
        Write-Output "RPT does not exist, creating..."
        if ($sessioninfo.SourceRemote) {
          $command = { Add-AdfsRelyingPartyTrust -Name $Using:adfsRPT.Name -Identifier $Using:adfsRPT.Identifier }
          Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
          $command = { Get-AdfsRelyingPartyTrust -Name $Using:adfsRPT.Name }
          $SourceRPT = Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
        }
        else {
          Add-AdfsRelyingPartyTrust -Name $adfsRPT.Name -Identifier $adfsRPT.Identifier
          $SourceRPT = Get-AdfsRelyingPartyTrust -Name $adfsRPT.Name
        }
      }

      # Not every field is supported by set-AdfsRelyingPartyTrust, plus null entries are problematic, so we filter and convert as needed.
      $RPTSplat = @{ }
      $RPTSplat.TargetRelyingParty = $SourceRPT

      $adfsRPT.psobject.properties | ForEach-Object {     
        $tmpName = $_.Name
        $tmpValue = $_.Value
        switch ($tmpName) {
          ClaimsAccepted {$RPTSplat.ClaimAccepted = $tmpValue }
          default { $RPTSplat[$tmpName] = $tmpValue }
        }
      }
    
      Write-Output $RPTSplat.TargetRelyingParty
      Write-Output $RPTSplat.TargetRelyingParty.gettype()

      # Finally work can be done.
      Write-Output "importing content"
      if ($sessioninfo.SourceRemote) {
        $command = { Set-AdfsRelyingPartyTrust @Using:RPTSplat }
        Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
      }
      else {
        Set-AdfsRelyingPartyTrust @RPTSplat
      }
    } # End RPT Loop
  }

  End {
    #tear down sessions
    sessionconfig -Method close -SessionInfo $sessioninfo
  }
}