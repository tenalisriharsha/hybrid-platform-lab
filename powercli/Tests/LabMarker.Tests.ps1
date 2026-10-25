# Pure unit tests for the owner/expiry/protected marker abstraction, with VMware.PowerCLI
# cmdlets mocked. These run without vcsim and without any VI connection; they are what
# proves the tag code path is wired correctly, since vcsim's vCenter simulation cannot
# exercise real tag assignment (see Private/LabMarkerTags.ps1).

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'HybridLab') -Force
}

Describe 'ConvertTo-LabMarkerNotes / ConvertFrom-LabMarkerNotes' {
    It "round-trips owner/expiry/protected through the Notes string" {
        InModuleScope HybridLab {
            $notes = ConvertTo-LabMarkerNotes -Owner 'alice@example.com' -Expiry '2026-11-01T00:00:00Z' -Protected $true
            $parsed = ConvertFrom-LabMarkerNotes -Notes $notes

            $parsed.Owner | Should -Be 'alice@example.com'
            $parsed.Expiry | Should -Be '2026-11-01T00:00:00Z'
            $parsed.Protected | Should -BeTrue
        }
    }

    It "returns `$null for a Notes string this module did not write" {
        InModuleScope HybridLab {
            ConvertFrom-LabMarkerNotes -Notes 'some unrelated note' | Should -BeNullOrEmpty
            ConvertFrom-LabMarkerNotes -Notes $null | Should -BeNullOrEmpty
        }
    }
}

Describe 'Set-LabVMMarker strategy selection' {
    <#
        These mock Set-LabVMNotesMarker and Set-LabVMMarkerAsTag - the two seams
        Set-LabVMMarker branches between - rather than the compiled VMware cmdlets they
        call internally (Set-VM, New-TagCategory, ...). Pester cannot cleanly mock those:
        they carry strongly-typed parameters (e.g. -VM : VirtualMachine[]) that reject a
        fake test double before the mock body ever runs. The tag path's real cmdlet calls
        are documented, not unit-tested, and are never exercised against vcsim either (see
        LabMarkerTags.ps1) - only a real vCenter proves them.
    #>
    BeforeEach {
        InModuleScope HybridLab {
            $global:DefaultVIServer = $null
        }
    }

    AfterEach {
        InModuleScope HybridLab {
            $global:DefaultVIServer = $null
        }
    }

    It "writes a Notes marker when Strategy is 'Notes'" {
        InModuleScope HybridLab {
            Mock Set-LabVMNotesMarker { }
            Mock Set-LabVMMarkerAsTag { }
            $fakeVm = [PSCustomObject]@{ Name = 'fake-vm' }

            Set-LabVMMarker -VM $fakeVm -Owner 'bob@example.com' -Expiry '2026-12-01T00:00:00Z' -Protected $false -Strategy 'Notes'

            Should -Invoke Set-LabVMNotesMarker -Times 1 -ParameterFilter {
                $Notes -like 'hybridlab:v1|owner=bob@example.com*'
            }
            Should -Invoke Set-LabVMMarkerAsTag -Times 0
        }
    }

    It "assigns tags and skips Notes when Strategy is 'Tag' and tagging succeeds" {
        InModuleScope HybridLab {
            Mock Set-LabVMMarkerAsTag { }
            Mock Set-LabVMNotesMarker { }
            $fakeVm = [PSCustomObject]@{ Name = 'fake-vm' }

            Set-LabVMMarker -VM $fakeVm -Owner 'carol@example.com' -Expiry '2026-12-01T00:00:00Z' -Protected $false -Strategy 'Tag'

            Should -Invoke Set-LabVMMarkerAsTag -Times 1
            Should -Invoke Set-LabVMNotesMarker -Times 0
        }
    }

    It "throws when Strategy is 'Tag' and tagging fails" {
        InModuleScope HybridLab {
            Mock Set-LabVMMarkerAsTag { throw 'no lookup service' }
            Mock Set-LabVMNotesMarker { }
            $fakeVm = [PSCustomObject]@{ Name = 'fake-vm' }

            { Set-LabVMMarker -VM $fakeVm -Owner 'dave@example.com' -Expiry '2026-12-01T00:00:00Z' -Protected $false -Strategy 'Tag' } |
                Should -Throw

            Should -Invoke Set-LabVMNotesMarker -Times 0
        }
    }

    It "falls back to Notes when Strategy is 'Auto' on a vCenter connection where tagging fails" {
        InModuleScope HybridLab {
            $global:DefaultVIServer = [PSCustomObject]@{ ProductLine = 'vpx' }
            Mock Set-LabVMMarkerAsTag { throw 'no lookup service' }
            Mock Set-LabVMNotesMarker { }
            $fakeVm = [PSCustomObject]@{ Name = 'fake-vm' }

            Set-LabVMMarker -VM $fakeVm -Owner 'erin@example.com' -Expiry '2026-12-01T00:00:00Z' -Protected $false -Strategy 'Auto' -WarningAction SilentlyContinue

            Should -Invoke Set-LabVMMarkerAsTag -Times 1
            Should -Invoke Set-LabVMNotesMarker -Times 1 -ParameterFilter {
                $Notes -like 'hybridlab:v1|owner=erin@example.com*'
            }
        }
    }

    It "never attempts tags when Strategy is 'Auto' and the server is not vCenter" {
        InModuleScope HybridLab {
            $global:DefaultVIServer = [PSCustomObject]@{ ProductLine = 'embeddedEsx' }
            Mock Set-LabVMMarkerAsTag { throw 'should not be called' }
            Mock Set-LabVMNotesMarker { }
            $fakeVm = [PSCustomObject]@{ Name = 'fake-vm' }

            Set-LabVMMarker -VM $fakeVm -Owner 'frank@example.com' -Expiry '2026-12-01T00:00:00Z' -Protected $false -Strategy 'Auto'

            Should -Invoke Set-LabVMMarkerAsTag -Times 0
            Should -Invoke Set-LabVMNotesMarker -Times 1
        }
    }
}
