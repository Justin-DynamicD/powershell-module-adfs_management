function convertorganization {

  [CmdletBinding()]
  Param
  (
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet("tocustom","fromcustom")]
    [string] $Method = "tocustom",

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [PsObject] $organization

  )

  $ErrorActionPreference = "Stop"

  If ($null -eq $organization) { return $null; end }
  $customOrganization = $null

  switch ($Method) {
    tocustom {
      # trim object down to configuratble entries only
      $customOrganization = New-Object -TypeName PSObject 
      $noteCount = 0
      $organization.psobject.properties | ForEach-Object {
        $tmpName = $_.Name
        $tmpValue = $_.Value
        If ($tmpValue) {
          $customContact | Add-Member NoteProperty -Name $tmpName -Value $tmpValue
          $noteCount ++
        }
      }
      #check the number of properties added; if 0 then null the object
      If ($noteCount -eq 0) { $customOrganization = $null }
    }

    fromcustom {

      $splatOrganization = @{}
      $organization.psobject.properties | ForEach-Object {
        $tmpName = $_.Name
        $tmpValue = $_.Value
        If ($tmpValue) {
          $splatOrganization[$tmpName] = $tmpValue
        }
      }
      # only attempt to build splat isn't emptyu
      If ($splatOrganization -ne @{}) {
        $customOrganization = New-AdfsOrganization @splatOrganization
      }
    }
  }

  return $customOrganization
}