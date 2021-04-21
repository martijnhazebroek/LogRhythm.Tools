using namespace System
using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Net.Http

Function Add-LrFileToCase {
    <#
    .SYNOPSIS
        Add-LrFileToCase attaches file evidence to an existing case.
    .DESCRIPTION
        Add-LrFileToCase attaches file evidence to an existing case.
    .PARAMETER Id
        The Id of the case for which to add file evidence.
    .PARAMETER File
        Path to a file to upload.
    .PARAMETER PassThru
        Return the object representing the added evidence.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
        Note: You can bypass the need to provide a Credential by setting
        the preference variable $LrtConfig.LogRhythm.ApiKey
        with a valid Api Token.
    .INPUTS
        [object] -> Id (case id)
    .OUTPUTS
        If the PassThru parameter is provided, a PSCustomObject representing
        the evidence added and its status will be returned.
    .EXAMPLE

    .NOTES

    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNull()]
        [object] $Id,


        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [FileInfo] $File,


        [Parameter(Mandatory = $false, Position = 2)]
        [switch] $PassThru,


        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateNotNull()]
        [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
    )

    
    Begin {
        $Me = $MyInvocation.MyCommand.Name

        $BaseUrl = $LrtConfig.LogRhythm.CaseBaseUrl
        $Token = $Credential.GetNetworkCredential().Password

        # Enable self-signed certificates and Tls1.2
        Enable-TrustAllCertsPolicy

        # Request Headers
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $Token")
        $Headers.Add("Content-Type","application/json")

        # Request URI   
        $Method = $HttpMethod.Post
    }


    Process {
        # Test CaseID Format
        $IdStatus = Test-LrCaseIdFormat $Id
        if ($IdStatus.IsValid -eq $true) {
            $CaseNumber = $IdStatus.CaseNumber
        } else {
            return $IdStatus
        }

        $RequestUrl = $BaseUrl + "/cases/$CaseNumber/evidence/file/"

        # Validate file exists
        if (! $file.Exists) {
            throw [FileNotFoundException] "Unable to find provided file $($File.Name)"
        }

        # Request Body
        $MpContent = [MultipartFormDataContent]::new()
        $FileStream = [FileStream]::new($File.FullName, [FileMode]::Open)
        $FileHeader = [Headers.ContentDispositionHeaderValue]::new("form-data")
        $FileHeader.Name = "file"
        $FileHeader.FileName = $File.FullName
        $FileContent = [StreamContent]::new($FileStream)
        $FileContent.Headers.ContentDisposition = $FileHeader
        $MpContent.Add($FileContent)

        $Body = $MpContent
        Write-Verbose "[$Me] Calling Url: $RequestUrl"
        Write-Verbose "[$Me] Request Body:`n$Body"

        # REQUEST
        if ($PSEdition -eq 'Core'){
            try {
                $Response = Invoke-RestMethod $RequestUrl -Headers $Headers -Method $Method -Body $Body -SkipCertificateCheck
            }
            catch {
                $ExceptionMessage = ($_.Exception.Message).ToString().Trim()
                Write-Verbose "Exception Message: $ExceptionMessage"
                return $ExceptionMessage
            }
        } else {
            throw [NotSupportedException] "$Me is only supported in PowerShell Core edition 7+"
        }

        # Return
        if ($PassThru) {
            return $Response    
        }        
    }


    End { }
}