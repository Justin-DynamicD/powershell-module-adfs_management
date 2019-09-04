function set-sessioncontext {
  <#
  .DESCRIPTION
    sets up and tears down remote pssessions.
    passes a cmd through as needed

  .EXAMPLE
    $sessioninfo = set-sessioncontext -Method open -server server01 -credentials $mycreds

  .EXAMPLE
    set-sessioncontext $SessionInfo "get-adfsclient"

  .EXAMPLE
    set-sessioncontext $SessionInfo -method close
  #>

  [CmdletBinding()]
  Param
  (
    # Param1 help description
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [hashtable] $SessionInfo,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 1)]
    [scriptblock] $InlineCMD,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet("open","pipe","close")]
    [string] $Method = "pipe",

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
      if ($Server -ne $env:COMPUTERNAME) {
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

    pipe {
      # Query existing ADFSClients
      if ($SessionInfo.SourceRemote) {
        Invoke-Command -Session $SessionInfo.SessionData -ScriptBlock $InlineCMD
      }
      else {
        Invoke-Command -ScriptBlock $InlineCMD
      }
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