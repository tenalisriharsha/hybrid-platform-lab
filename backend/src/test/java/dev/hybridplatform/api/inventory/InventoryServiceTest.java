package dev.hybridplatform.api.inventory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import dev.hybridplatform.api.inventory.domain.Datastore;
import dev.hybridplatform.api.inventory.domain.Host;
import dev.hybridplatform.api.inventory.domain.PowerState;
import dev.hybridplatform.api.inventory.domain.VirtualMachine;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class InventoryServiceTest {

    private SimpleMeterRegistry meterRegistry;
    private InventoryService inventoryService;

    @BeforeEach
    void setUp() {
        meterRegistry = new SimpleMeterRegistry();
        inventoryService = new InventoryService(meterRegistry);
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

    @Test
    void syncReplacesSeedDataWithNewEstate() {
        Datastore datastore = new Datastore("ds-synced", "synced-ds", 1024, 512);
        Host host = new Host("host-synced", "synced-host", "synced-cluster", 8, 16384, List.of(datastore.id()));
        VirtualMachine vm = new VirtualMachine(
                "vm-synced", "synced-vm", host.id(), PowerState.POWERED_ON, 2, 4096);

        SyncResult result = inventoryService.sync(List.of(host), List.of(vm), List.of(datastore));

        assertThat(result.hostCount()).isEqualTo(1);
        assertThat(result.vmCount()).isEqualTo(1);
        assertThat(result.datastoreCount()).isEqualTo(1);
        assertThat(result.syncedAt()).isNotNull();

        assertThat(inventoryService.listHosts()).containsExactly(host);
        assertThat(inventoryService.listVms()).containsExactly(vm);
        assertThat(inventoryService.listDatastores()).containsExactly(datastore);
        assertThatThrownBy(() -> inventoryService.getHost("host-1"))
                .isInstanceOf(InventoryItemNotFoundException.class);
    }

    @Test
    void syncRejectsVmReferencingUnknownHost() {
        Host host = new Host("host-synced", "synced-host", "synced-cluster", 8, 16384, List.of());
        VirtualMachine orphan = new VirtualMachine(
                "vm-orphan", "orphan", "host-missing", PowerState.POWERED_ON, 2, 4096);

        assertThatThrownBy(() -> inventoryService.sync(List.of(host), List.of(orphan), List.of()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("host-missing");

        assertThat(inventoryService.listHosts()).hasSize(2);
    }

    @Test
    void syncWithEmptyEstateClearsInventory() {
        SyncResult result = inventoryService.sync(List.of(), List.of(), List.of());

        assertThat(result.hostCount()).isZero();
        assertThat(inventoryService.listHosts()).isEmpty();
        assertThat(inventoryService.listVms()).isEmpty();
        assertThat(inventoryService.listDatastores()).isEmpty();
    }

    @Test
    void registersInventorySizeGauges() {
        assertThat(meterRegistry.get("platform_inventory_hosts").gauge().value()).isEqualTo(2.0);
        assertThat(meterRegistry.get("platform_inventory_vms").gauge().value()).isEqualTo(3.0);
        assertThat(meterRegistry.get("platform_inventory_datastores").gauge().value()).isEqualTo(2.0);
    }

    @Test
    void summaryReflectsSeededInventory() {
        InventorySummary summary = inventoryService.summary();

        assertThat(summary.hostCount()).isEqualTo(2);
        assertThat(summary.vmCount()).isEqualTo(3);
        assertThat(summary.datastoreCount()).isEqualTo(2);
        assertThat(summary.vmsPoweredOn()).isEqualTo(2);
        assertThat(summary.vmsPoweredOff()).isEqualTo(1);
        assertThat(summary.vmsSuspended()).isZero();
        assertThat(summary.totalDatastoreCapacityGb()).isEqualTo(2048 + 4096);
        assertThat(summary.totalDatastoreFreeGb()).isEqualTo(1200 + 3100);
    }

    @Test
    void summaryTracksPowerStateChanges() {
        inventoryService.setVmPowerState("vm-3", PowerState.POWERED_ON);

        InventorySummary summary = inventoryService.summary();

        assertThat(summary.vmsPoweredOn()).isEqualTo(3);
        assertThat(summary.vmsPoweredOff()).isZero();
    }

    @Test
    void summaryTracksSyncedEstate() {
        Datastore datastore = new Datastore("ds-synced", "synced-ds", 1024, 512);
        Host host = new Host("host-synced", "synced-host", "synced-cluster", 8, 16384, List.of(datastore.id()));
        VirtualMachine vm = new VirtualMachine(
                "vm-synced", "synced-vm", host.id(), PowerState.SUSPENDED, 2, 4096);

        inventoryService.sync(List.of(host), List.of(vm), List.of(datastore));

        InventorySummary summary = inventoryService.summary();
        assertThat(summary.hostCount()).isEqualTo(1);
        assertThat(summary.vmsSuspended()).isEqualTo(1);
        assertThat(summary.totalDatastoreCapacityGb()).isEqualTo(1024);
        assertThat(summary.totalDatastoreFreeGb()).isEqualTo(512);
    }

    @Test
    void inventorySizeGaugesTrackSyncedEstate() {
        Datastore datastore = new Datastore("ds-synced", "synced-ds", 1024, 512);
        Host host = new Host("host-synced", "synced-host", "synced-cluster", 8, 16384, List.of(datastore.id()));
        VirtualMachine vm = new VirtualMachine(
                "vm-synced", "synced-vm", host.id(), PowerState.POWERED_ON, 2, 4096);

        inventoryService.sync(List.of(host), List.of(vm), List.of(datastore));

        assertThat(meterRegistry.get("platform_inventory_hosts").gauge().value()).isEqualTo(1.0);
        assertThat(meterRegistry.get("platform_inventory_vms").gauge().value()).isEqualTo(1.0);
        assertThat(meterRegistry.get("platform_inventory_datastores").gauge().value()).isEqualTo(1.0);
    }
}
