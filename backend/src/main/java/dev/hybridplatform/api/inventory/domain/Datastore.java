package dev.hybridplatform.api.inventory.domain;

public record Datastore(String id, String name, long capacityGb, long freeGb) {

    public Datastore {
        if (id == null || id.isBlank()) {
            throw new IllegalArgumentException("Datastore id must not be blank");
        }
        if (freeGb > capacityGb) {
            throw new IllegalArgumentException("Datastore freeGb cannot exceed capacityGb");
        }
    }
}
