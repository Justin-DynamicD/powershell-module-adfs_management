function convertperson {

  [CmdletBinding()]
  Param
  (
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet("tocustom","fromcustom")]
    [string] $Method = "tocustom",

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [PsObject] $Contact

  )

  $ErrorActionPreference = "Stop"

  If ($null -eq $Contact) { return $null; end }
  $customContact = $null

  switch ($Method) {
    tocustom {

      # trim object down to configuratble entries only
      $customContact = New-Object -TypeName PSObject 
      $noteCount = 0
      $Contact.psobject.properties | ForEach-Object {
        $tmpName = $_.Name
        $tmpValue = $_.Value
        If ($tmpValue) {
          switch ($tmpName) {
            ContactType {} # ensure we skip this value
            default { 
              $customContact | Add-Member NoteProperty -Name $tmpName -Value $tmpValue
              $noteCount ++
            }
          }
        }
      }
      #check the number of prperties added; if 0 then null the object
      If ($noteCount -eq 0) { $customContact = $null }
    }

    fromcustom {

      $splatPerson = @{}
      $Contact.psobject.properties | ForEach-Object {
        $tmpName = $_.Name
        $tmpValue = $_.Value
        If ($tmpValue) {
          switch ($tmpName) {
            EmailAddresses { $splatPerson.EmailAddress = $tmpValue }
            PhoneNumbers { $splatPerson.TelephoneNumber = $tmpValue }
            default { $splatPerson[$tmpName] = $tmpValue }
          }
        }
      }
      # only attempt to build splat isn't emptyu
      If ($splatPerson -ne @{}) {
        $customContact = New-AdfsContactPerson @splatPerson
      }
    }
  }

  return $customContact
}