package dev.hybridplatform.api.inventory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import dev.hybridplatform.api.inventory.domain.Host;
import dev.hybridplatform.api.inventory.domain.PowerState;
import dev.hybridplatform.api.inventory.domain.VirtualMachine;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class InventoryServiceTest {

    private InventoryService inventoryService;

    @BeforeEach
    void setUp() {
        inventoryService = new InventoryService();
    }

    @Test
    void seedsHostsVmsAndDatastoresOnStartup() {
        assertThat(inventoryService.listHosts()).hasSize(2);
        assertThat(inventoryService.listVms()).hasSize(3);
        assertThat(inventoryService.listDatastores()).hasSize(2);
    }

    @Test
    void getHostReturnsSeededHost() {
        Host host = inventoryService.getHost("host-1");
        assertThat(host.name()).isEqualTo("esx-lab-01");
        assertThat(host.cluster()).isEqualTo("cluster-lab");
    }

    @Test
    void getHostThrowsWhenMissing() {
        assertThatThrownBy(() -> inventoryService.getHost("does-not-exist"))
                .isInstanceOf(InventoryItemNotFoundException.class)
                .hasMessageContaining("does-not-exist");
    }

    @Test
    void getVmThrowsWhenMissing() {
        assertThatThrownBy(() -> inventoryService.getVm("does-not-exist"))
                .isInstanceOf(InventoryItemNotFoundException.class);
    }

    @Test
    void getDatastoreThrowsWhenMissing() {
        assertThatThrownBy(() -> inventoryService.getDatastore("does-not-exist"))
                .isInstanceOf(InventoryItemNotFoundException.class);
    }

    @Test
    void setVmPowerStateUpdatesAndReturnsNewState() {
        VirtualMachine updated = inventoryService.setVmPowerState("vm-3", PowerState.POWERED_ON);

        assertThat(updated.powerState()).isEqualTo(PowerState.POWERED_ON);
        assertThat(inventoryService.getVm("vm-3").powerState()).isEqualTo(PowerState.POWERED_ON);
    }

    @Test
    void setVmPowerStateThrowsForUnknownVm() {
        assertThatThrownBy(() -> inventoryService.setVmPowerState("vm-missing", PowerState.POWERED_ON))
                .isInstanceOf(InventoryItemNotFoundException.class);
    }

    @Test
    void addVmRejectsUnknownHost() {
        VirtualMachine orphan = new VirtualMachine("vm-orphan", "orphan", "host-missing", PowerState.POWERED_OFF, 1, 1024);

        assertThatThrownBy(() -> inventoryService.addVm(orphan))
                .isInstanceOf(InventoryItemNotFoundException.class)
                .hasMessageContaining("host-missing");
    }

    @Test
    void addVmSucceedsForKnownHostAndIsListed() {
        VirtualMachine vm = new VirtualMachine("vm-new", "new-vm", "host-1", PowerState.POWERED_OFF, 2, 2048);

        inventoryService.addVm(vm);

        assertThat(inventoryService.listVms()).extracting(VirtualMachine::id).contains("vm-new");
    }

    @Test
    void addHostMakesItRetrievable() {
        Host newHost = new Host("host-3", "esx-lab-03", "cluster-lab", 16, 65536, List.of());

        inventoryService.addHost(newHost);

        assertThat(inventoryService.getHost("host-3")).isEqualTo(newHost);
    }
}
