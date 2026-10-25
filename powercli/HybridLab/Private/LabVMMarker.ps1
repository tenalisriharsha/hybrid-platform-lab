function Test-LabServerIsVCenter {
    <#
        .SYNOPSIS
        True when the active connection is a vCenter server (tags are only possible there).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $server = $global:DefaultVIServer
    return [bool]($server -and $server.ProductLine -eq 'vpx')
}

function Set-LabVMMarker {
    <#
        .SYNOPSIS
        Marks a VM with owner/expiry/protected, using vSphere tags when the connected
        server supports them and falling back to a Notes marker otherwise.
        .PARAMETER Strategy
        'Auto' (default) tries tags on a vCenter connection and falls back to Notes on any
        failure; 'Tag' forces tags (and throws if they are unavailable); 'Notes' always uses
        the Notes marker. vcsim's vCenter simulation always fails the tag attempt (no Lookup
        Service), so 'Auto' against vcsim always lands on Notes - this is documented, expected
        behaviour, not a bug to work around.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSObject] $VM,
        [Parameter(Mandatory)] [string] $Owner,
        [Parameter(Mandatory)] [string] $Expiry,
        [bool] $Protected = $false,
        [ValidateSet('Auto', 'Tag', 'Notes')] [string] $Strategy = 'Auto'
    )

    $attemptTag = ($Strategy -eq 'Tag') -or ($Strategy -eq 'Auto' -and (Test-LabServerIsVCenter))

    if ($attemptTag) {
        try {
            Set-LabVMMarkerAsTag -VM $VM -Owner $Owner -Expiry $Expiry -Protected $Protected
            return
        }
        catch {
            if ($Strategy -eq 'Tag') {
                throw
            }
            Write-Warning "Tag-based markers are unavailable on this server ($($_.Exception.Message)); falling back to a Notes marker. A real vCenter with the Lookup Service available should use tags."
        }
    }

    Set-LabVMNotesMarker -VM $VM -Notes (ConvertTo-LabMarkerNotes -Owner $Owner -Expiry $Expiry -Protected $Protected)
}

function Get-LabVMMarker {
    <#
        .SYNOPSIS
        Reads a VM's owner/expiry/protected marker, trying tags first (on vCenter) and
        falling back to the Notes marker. Returns Strategy = 'Unmarked' with Protected = $false
        for a VM this module has never marked.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [PSObject] $VM
    )

    if (Test-LabServerIsVCenter) {
        try {
            $tagMarker = Get-LabVMMarkerFromTags -VM $VM
            if ($tagMarker) {
                $tagMarker | Add-Member -NotePropertyName 'Strategy' -NotePropertyValue 'Tag' -Force
                return $tagMarker
            }
        }
        catch {
            Write-Verbose "Tags unsupported or unreachable on this server ($($_.Exception.Message)); falling through to the Notes marker."
        }
    }

    $notesMarker = ConvertFrom-LabMarkerNotes -Notes $VM.Notes
    if ($notesMarker) {
        $notesMarker | Add-Member -NotePropertyName 'Strategy' -NotePropertyValue 'Notes' -Force
        return $notesMarker
    }

    [PSCustomObject]@{ Owner = $null; Expiry = $null; Protected = $false; Strategy = 'Unmarked' }
}
