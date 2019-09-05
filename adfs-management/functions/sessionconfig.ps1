function sessionconfig {
  <#
  .DESCRIPTION
    sets up and tears down remote pssessions.

  .EXAMPLE
    $sessioninfo = set-sessioncontext -Method open -server server01 -credentials $mycreds

  .EXAMPLE
    set-sessioncontext $SessionInfo -method close
  #>

  [CmdletBinding()]
  Param
  (
    # Param1 help description
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [hashtable] $SessionInfo,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet("open","close")]
    [string] $Method = "open",

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [string] $Server = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [System.Management.Automation.PSCredential] $Credential
  )

  $ErrorActionPreference = "Stop"

  switch ($Method) {
    open {
      
      # create an empty hashtable and populate connection info
      $pssession = @{ }
      if ($Credential) {
        $pssession.Credential = $Credential
      }
    
      # Establish Source connections
      if (($Server -ne $env:COMPUTERNAME) -and ($Server -ne (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain)) {
        $pssession.ComputerName = $Server
        $newpssession = New-PSSession @pssession

        #add remaining parameters
        $pssession.SourceRemote = $true
        $pssession.SessionData = $newpssession

      }
      else { $pssession.SourceRemote = $false }

      #Remove Credentials for cleanliness and return
      $pssession.Remove("Credential")
      return $pssession
    }

    close {
      #tear down sessions
      if (!$SessionInfo) { write-warning "Missing -SessionInfo, nothing to do" }
      if ($SessionInfo.SourceRemote) {
        Remove-PSSession -Session $SessionInfo.SessionData
      }
    }
  }
}