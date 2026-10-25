$script:LabMarkerPrefix = 'hybridlab:v1|'

function ConvertTo-LabMarkerNotes {
    <#
        .SYNOPSIS
        Builds the VM Notes string used to mark a lab VM when tags are unavailable.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Owner,
        [Parameter(Mandatory)] [string] $Expiry,
        [bool] $Protected = $false
    )

    $protectedText = $Protected.ToString().ToLowerInvariant()
    "$($script:LabMarkerPrefix)owner=$Owner|expiry=$Expiry|protected=$protectedText"
}

function ConvertFrom-LabMarkerNotes {
    <#
        .SYNOPSIS
        Parses a VM Notes string back into owner/expiry/protected, or returns $null
        if the Notes field was not written by Set-LabVMMarker.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string] $Notes
    )

    if ([string]::IsNullOrEmpty($Notes) -or -not $Notes.StartsWith($script:LabMarkerPrefix)) {
        return $null
    }

    $body = $Notes.Substring($script:LabMarkerPrefix.Length)
    $fields = @{}
    foreach ($pair in ($body -split '\|')) {
        $kv = $pair -split '=', 2
        if ($kv.Count -eq 2) {
            $fields[$kv[0]] = $kv[1]
        }
    }

    [PSCustomObject]@{
        Owner     = $fields['owner']
        Expiry    = $fields['expiry']
        Protected = ($fields['protected'] -eq 'true')
    }
}

function Set-LabVMNotesMarker {
    <#
        .SYNOPSIS
        Thin wrapper around Set-VM so Set-LabVMMarker's branching logic can be unit-tested
        by mocking this function - Pester cannot cleanly mock Set-VM itself, since it is a
        compiled cmdlet with a strongly-typed -VM parameter that rejects a test double.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSObject] $VM,
        [Parameter(Mandatory)] [string] $Notes
    )

    Set-VM -VM $VM -Notes $Notes -Confirm:$false | Out-Null
}
