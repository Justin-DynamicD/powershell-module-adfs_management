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
    getcustom {

      # this command block needs to run locally and transform the object to generic
      $command = {
        $Organization = (Get-AdfsProperties).OrganizationInfo
        $customOrganization = @{} 
        $noteCount = 0
        $Organization.psobject.properties | ForEach-Object {
          $tmpName = $_.Name
          $tmpValue = $_.Value
          If ($tmpValue) {
            $customOrganization[$tmpName] = $tmpValue
            $noteCount ++
          }
        }
        #check the number of prperties added; if 0 then null the object
        If ($noteCount -eq 0) { $customOrganization = $null }
        return $customOrganization
      }

      # use sessioninfo to determine local or remote execution
      if ($Sessioninfo.SourceRemote){
        $customOrganization = Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
      }
      else {
        $customOrganization = Invoke-Command -ScriptBlock $command
      }

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