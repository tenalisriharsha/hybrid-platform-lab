package dev.hybridplatform.api.inventory.web;

import dev.hybridplatform.api.inventory.InventoryService;
import dev.hybridplatform.api.inventory.InventorySummary;
import dev.hybridplatform.api.inventory.SyncResult;
import dev.hybridplatform.api.inventory.domain.Datastore;
import dev.hybridplatform.api.inventory.domain.Host;
import dev.hybridplatform.api.inventory.domain.VirtualMachine;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class InventoryController {

    private final InventoryService inventoryService;

    public InventoryController(InventoryService inventoryService) {
        this.inventoryService = inventoryService;
    }

    @GetMapping("/hosts")
    public List<Host> listHosts() {
        return inventoryService.listHosts();
    }

    @GetMapping("/hosts/{id}")
    public Host getHost(@PathVariable String id) {
        return inventoryService.getHost(id);
    }

    @GetMapping("/vms")
    public List<VirtualMachine> listVms() {
        return inventoryService.listVms();
    }

    @GetMapping("/vms/{id}")
    public VirtualMachine getVm(@PathVariable String id) {
        return inventoryService.getVm(id);
    }

    @PostMapping("/vms/{id}/power")
    public VirtualMachine setVmPower(@PathVariable String id, @RequestBody PowerStateRequest request) {
        return inventoryService.setVmPowerState(id, request.state());
    }

    @GetMapping("/datastores")
    public List<Datastore> listDatastores() {
        return inventoryService.listDatastores();
    }

    @GetMapping("/datastores/{id}")
    public Datastore getDatastore(@PathVariable String id) {
        return inventoryService.getDatastore(id);
    }

    @PostMapping("/sync")
    public SyncResult sync(@RequestBody SyncRequest request) {
        return inventoryService.sync(request.hosts(), request.vms(), request.datastores());
    }

    @GetMapping("/summary")
    public InventorySummary summary() {
        return inventoryService.summary();
    }
}
