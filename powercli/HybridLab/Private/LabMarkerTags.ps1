$script:LabTagCategories = @('hybridlab-owner', 'hybridlab-expiry', 'hybridlab-protected')

function Set-LabVMMarkerAsTag {
    <#
        .SYNOPSIS
        Marks a VM using vSphere tags (one category per field: owner, expiry, protected).
        .NOTES
        Requires the vCenter Lookup Service. vcsim's vCenter simulation does not implement
        it, so this path is never exercised against vcsim - only against a real vCenter, and
        unit-tested here with mocks. See docs/modernization.md and the module README for detail.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSObject] $VM,
        [Parameter(Mandatory)] [string] $Owner,
        [Parameter(Mandatory)] [string] $Expiry,
        [bool] $Protected = $false
    )

    $values = @{
        'hybridlab-owner'     = $Owner
        'hybridlab-expiry'    = $Expiry
        'hybridlab-protected' = $Protected.ToString().ToLowerInvariant()
    }

    foreach ($categoryName in $script:LabTagCategories) {
        $category = Get-TagCategory -Name $categoryName -ErrorAction SilentlyContinue
        if (-not $category) {
            $category = New-TagCategory -Name $categoryName -Cardinality Single -EntityType VirtualMachine -Confirm:$false
        }

        $tagValue = $values[$categoryName]
        $tag = Get-Tag -Category $category -Name $tagValue -ErrorAction SilentlyContinue
        if (-not $tag) {
            $tag = New-Tag -Category $category -Name $tagValue -Confirm:$false
        }

        Get-TagAssignment -Entity $VM -ErrorAction SilentlyContinue |
            Where-Object { $_.Tag.Category.Name -eq $categoryName } |
            Remove-TagAssignment -Confirm:$false

        New-TagAssignment -Entity $VM -Tag $tag -Confirm:$false | Out-Null
    }
}

function Get-LabVMMarkerFromTags {
    <#
        .SYNOPSIS
        Reads a VM's hybridlab-* tag assignments, or returns $null if none are set.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [PSObject] $VM
    )

    $assignments = Get-TagAssignment -Entity $VM -ErrorAction Stop
    if (-not $assignments) {
        return $null
    }

    $byCategory = @{}
    foreach ($assignment in $assignments) {
        $byCategory[$assignment.Tag.Category.Name] = $assignment.Tag.Name
    }

    if (-not $byCategory.ContainsKey('hybridlab-owner')) {
        return $null
    }

    [PSCustomObject]@{
        Owner     = $byCategory['hybridlab-owner']
        Expiry    = $byCategory['hybridlab-expiry']
        Protected = ($byCategory['hybridlab-protected'] -eq 'true')
    }
}
