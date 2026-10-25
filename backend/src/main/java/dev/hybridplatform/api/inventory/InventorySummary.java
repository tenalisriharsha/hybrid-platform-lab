package dev.hybridplatform.api.inventory;

/**
 * A dashboard-friendly rollup of the current inventory, so UI clients don't
 * need to fetch every host/VM/datastore or parse the Prometheus text format
 * just to render a few headline numbers.
 */
public record InventorySummary(
        int hostCount,
        int vmCount,
        int datastoreCount,
        int vmsPoweredOn,
        int vmsPoweredOff,
        int vmsSuspended,
        long totalDatastoreCapacityGb,
        long totalDatastoreFreeGb) {
}
