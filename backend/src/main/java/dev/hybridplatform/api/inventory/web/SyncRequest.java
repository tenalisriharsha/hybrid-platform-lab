package dev.hybridplatform.api.inventory.web;

import dev.hybridplatform.api.inventory.domain.Datastore;
import dev.hybridplatform.api.inventory.domain.Host;
import dev.hybridplatform.api.inventory.domain.VirtualMachine;
import java.util.List;

/**
 * Payload posted by the PowerCLI sync module (or any other inventory source)
 * to replace the platform's in-memory inventory in one atomic operation.
 */
public record SyncRequest(List<Host> hosts, List<VirtualMachine> vms, List<Datastore> datastores) {

    public SyncRequest {
        hosts = hosts == null ? List.of() : List.copyOf(hosts);
        vms = vms == null ? List.of() : List.copyOf(vms);
        datastores = datastores == null ? List.of() : List.copyOf(datastores);
    }
}
