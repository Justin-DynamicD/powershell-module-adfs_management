function convertorganization {

  [CmdletBinding()]
  Param
  (
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet("getcustom","applycustom")]
    [string] $Method = "getcustom",

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [PsObject] $Organization,

    [Parameter(Mandatory = $false)]
    [hashtable] $SessionInfo = @{ SourceRemote = $false }

  )

  $ErrorActionPreference = "Stop"
  $customOrganization = $null

  switch ($Method) {
    tocustom {

      #Nothing provided, nothing returned
      If ($null -eq $Organization) { return $null; end }

      # trim object down to configuratble entries only
      $customOrganization = New-Object -TypeName PSObject 
      $noteCount = 0
      $Organization.psobject.properties | ForEach-Object {
        $tmpName = $_.Name
        $tmpValue = $_.Value
        If ($tmpValue) {
          $customContact | Add-Member NoteProperty -Name $tmpName -Value $tmpValue
          $noteCount ++
        }
      }
      #check the number of properties added; if 0 then null the object
      If ($noteCount -eq 0) { $customOrganization = $null }
      return $customOrganization
    }

    applycustom {

      # If null is passed, simply apply to target
      If ($null -eq $Organization) {
        if ($Sessioninfo.SourceRemote){
          $command = { Set-AdfsProperties -OrganizationInfo $null }
          Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
        }
        else {
          Set-AdfsProperties -OrganizationInfo $null
        }
        end
      }

      $splatOrganization = @{}
      $Organization.psobject.properties | ForEach-Object {
        $tmpName = $_.Name
        $tmpValue = $_.Value
        If ($tmpValue) {
          $splatOrganization[$tmpName] = $tmpValue
        }
      }
      # only attempt to build splat isn't emptyu
      If ($splatOrganization -ne @{}) {
        if ($Sessioninfo.SourceRemote){
          $command = { Set-AdfsProperties -OrganizationInfo (New-AdfsOrganization @Using:splatOrganization) }
          Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
        }
        else {
          Set-AdfsProperties -OrganizationInfo (New-AdfsOrganization @splatOrganization)
        }
      }
    }
  }

}