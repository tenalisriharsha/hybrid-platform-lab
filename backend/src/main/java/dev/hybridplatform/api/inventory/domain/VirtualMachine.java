package dev.hybridplatform.api.inventory.domain;

public record VirtualMachine(
        String id,
        String name,
        String hostId,
        PowerState powerState,
        int cpuCount,
        int memoryMb) {

    public VirtualMachine {
        if (id == null || id.isBlank()) {
            throw new IllegalArgumentException("VirtualMachine id must not be blank");
        }
        if (hostId == null || hostId.isBlank()) {
            throw new IllegalArgumentException("VirtualMachine hostId must not be blank");
        }
        if (cpuCount <= 0) {
            throw new IllegalArgumentException("VirtualMachine cpuCount must be positive");
        }
    }

    public VirtualMachine withPowerState(PowerState newState) {
        return new VirtualMachine(id, name, hostId, newState, cpuCount, memoryMb);
    }
}
