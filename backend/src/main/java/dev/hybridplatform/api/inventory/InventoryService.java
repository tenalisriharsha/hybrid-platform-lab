package dev.hybridplatform.api.inventory;

import dev.hybridplatform.api.inventory.domain.Datastore;
import dev.hybridplatform.api.inventory.domain.Host;
import dev.hybridplatform.api.inventory.domain.PowerState;
import dev.hybridplatform.api.inventory.domain.VirtualMachine;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * Holds the platform's inventory of hosts, VMs, and datastores.
 *
 * <p>Seeded with sample data representing a simulated vSphere estate until
 * Phase 2 wires in a real sync from vcsim via the PowerCLI module.
 */
@Service
public class InventoryService {

    private final Map<String, Host> hosts = new ConcurrentHashMap<>();
    private final Map<String, VirtualMachine> vms = new ConcurrentHashMap<>();
    private final Map<String, Datastore> datastores = new ConcurrentHashMap<>();

    @Autowired
    public InventoryService(MeterRegistry meterRegistry) {
        seed();
        meterRegistry.gauge("platform_inventory_hosts", hosts, Map::size);
        meterRegistry.gauge("platform_inventory_vms", vms, Map::size);
        meterRegistry.gauge("platform_inventory_datastores", datastores, Map::size);
    }

    public InventoryService() {
        this(new SimpleMeterRegistry());
    }

    private void seed() {
        Datastore ds1 = new Datastore("ds-1", "datastore-lab-01", 2048, 1200);
        Datastore ds2 = new Datastore("ds-2", "datastore-lab-02", 4096, 3100);
        datastores.put(ds1.id(), ds1);
        datastores.put(ds2.id(), ds2);

        Host host1 = new Host("host-1", "esx-lab-01", "cluster-lab", 32, 131072, List.of(ds1.id(), ds2.id()));
        Host host2 = new Host("host-2", "esx-lab-02", "cluster-lab", 32, 131072, List.of(ds2.id()));
        hosts.put(host1.id(), host1);
        hosts.put(host2.id(), host2);

        VirtualMachine vm1 = new VirtualMachine("vm-1", "web-01", host1.id(), PowerState.POWERED_ON, 4, 8192);
        VirtualMachine vm2 = new VirtualMachine("vm-2", "db-01", host1.id(), PowerState.POWERED_ON, 8, 16384);
        VirtualMachine vm3 = new VirtualMachine("vm-3", "cache-01", host2.id(), PowerState.POWERED_OFF, 2, 4096);
        vms.put(vm1.id(), vm1);
        vms.put(vm2.id(), vm2);
        vms.put(vm3.id(), vm3);
    }

    public List<Host> listHosts() {
        return List.copyOf(hosts.values());
    }

    public Host getHost(String id) {
        Host host = hosts.get(id);
        if (host == null) {
            throw new InventoryItemNotFoundException("Host", id);
        }
        return host;
    }

    public List<VirtualMachine> listVms() {
        return List.copyOf(vms.values());
    }

    public VirtualMachine getVm(String id) {
        VirtualMachine vm = vms.get(id);
        if (vm == null) {
            throw new InventoryItemNotFoundException("VirtualMachine", id);
        }
        return vm;
    }

    public List<Datastore> listDatastores() {
        return List.copyOf(datastores.values());
    }

    public Datastore getDatastore(String id) {
        Datastore datastore = datastores.get(id);
        if (datastore == null) {
            throw new InventoryItemNotFoundException("Datastore", id);
        }
        return datastore;
    }

    public VirtualMachine setVmPowerState(String id, PowerState newState) {
        VirtualMachine current = getVm(id);
        VirtualMachine updated = current.withPowerState(newState);
        vms.put(id, updated);
        return updated;
    }

    public Collection<Host> addHost(Host host) {
        hosts.put(host.id(), host);
        return hosts.values();
    }

    public VirtualMachine addVm(VirtualMachine vm) {
        if (!hosts.containsKey(vm.hostId())) {
            throw new InventoryItemNotFoundException("Host", vm.hostId());
        }
        vms.put(vm.id(), vm);
        return vm;
    }

    /**
     * Atomically replaces the entire inventory with a freshly synced estate,
     * e.g. from the PowerCLI module pulling live data out of vcsim. The
     * sample data seeded at startup only ever serves as a fallback until the
     * first sync call lands.
     */
    public SyncResult sync(List<Host> newHosts, List<VirtualMachine> newVms, List<Datastore> newDatastores) {
        Set<String> hostIds = newHosts.stream().map(Host::id).collect(Collectors.toSet());
        for (VirtualMachine vm : newVms) {
            if (!hostIds.contains(vm.hostId())) {
                throw new IllegalArgumentException(
                        "Synced VM '" + vm.id() + "' references unknown host '" + vm.hostId() + "'");
            }
        }

        datastores.clear();
        newDatastores.forEach(datastore -> datastores.put(datastore.id(), datastore));
        hosts.clear();
        newHosts.forEach(host -> hosts.put(host.id(), host));
        vms.clear();
        newVms.forEach(vm -> vms.put(vm.id(), vm));

        return new SyncResult(hosts.size(), vms.size(), datastores.size(), Instant.now());
    }
}
