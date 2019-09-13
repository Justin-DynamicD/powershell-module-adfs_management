﻿function convertperson {

  [CmdletBinding()]
  Param
  (
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet("getcustom","applycustom")]
    [string] $Method = "getcustom",

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [PsObject] $Contact,

    [Parameter(Mandatory = $false)]
    [hashtable] $SessionInfo = @{ SourceRemote = $false }

  )

  $ErrorActionPreference = "Stop"
  $customContact = $null
  
  switch ($Method) {
    getcustom {

      # this command block needs to run locally and transform the object to a generic hashtable
      $command = {
        $Contact = (Get-AdfsProperties).ContactPerson
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
        return $customContact
      }

      # use sessioninfo to determine local or remote execution
      if ($Sessioninfo.SourceRemote){
        $customContact = Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
      }
      else {
        $customContact = Invoke-Command -ScriptBlock $command
      }
      return $customContact
    }

    applycustom {

      # If null is passed, simply apply to target
      If ($null -eq $Contact) {
        if ($Sessioninfo.SourceRemote){
          $command = { Set-AdfsProperties -ContactPerson $null }
          Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
        }
        else {
          Set-AdfsProperties -ContactPerson $null
        }
        end
      }

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
      # only attempt to apply if splat isn't empty
      If ($splatPerson -ne @{}) {
        if ($Sessioninfo.SourceRemote){
          $command = { Set-AdfsProperties -ContactPerson (New-AdfsContactPerson @Using:splatPerson) }
          Invoke-Command -Session $sessioninfo.SessionData -ScriptBlock $command
        }
        else {
          Set-AdfsProperties -ContactPerson (New-AdfsContactPerson @splatPerson)
        }
      }
    }
  }
}