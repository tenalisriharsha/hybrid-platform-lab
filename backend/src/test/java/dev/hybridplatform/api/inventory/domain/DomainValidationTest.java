package dev.hybridplatform.api.inventory.domain;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import org.junit.jupiter.api.Test;

class DomainValidationTest {

    @Test
    void datastoreRejectsBlankId() {
        assertThatThrownBy(() -> new Datastore("", "ds", 100, 10))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void datastoreRejectsFreeGreaterThanCapacity() {
        assertThatThrownBy(() -> new Datastore("ds-x", "ds", 100, 200))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void hostRejectsBlankId() {
        assertThatThrownBy(() -> new Host("", "host", "cluster", 8, 1024, List.of()))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void hostDefaultsNullDatastoreIdsToEmptyList() {
        Host host = new Host("host-x", "host", "cluster", 8, 1024, null);
        org.assertj.core.api.Assertions.assertThat(host.datastoreIds()).isEmpty();
    }

    @Test
    void virtualMachineRejectsBlankHostId() {
        assertThatThrownBy(() -> new VirtualMachine("vm-x", "vm", "", PowerState.POWERED_ON, 1, 1024))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void virtualMachineRejectsNonPositiveCpuCount() {
        assertThatThrownBy(() -> new VirtualMachine("vm-x", "vm", "host-1", PowerState.POWERED_ON, 0, 1024))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void withPowerStateReturnsNewInstanceWithUpdatedState() {
        VirtualMachine vm = new VirtualMachine("vm-x", "vm", "host-1", PowerState.POWERED_OFF, 2, 2048);

        VirtualMachine updated = vm.withPowerState(PowerState.POWERED_ON);

        org.assertj.core.api.Assertions.assertThat(updated.powerState()).isEqualTo(PowerState.POWERED_ON);
        org.assertj.core.api.Assertions.assertThat(vm.powerState()).isEqualTo(PowerState.POWERED_OFF);
    }
}
