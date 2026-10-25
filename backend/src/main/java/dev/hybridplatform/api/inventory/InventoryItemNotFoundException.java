package dev.hybridplatform.api.inventory;

public class InventoryItemNotFoundException extends RuntimeException {

    public InventoryItemNotFoundException(String kind, String id) {
        super(kind + " not found: " + id);
    }
}
