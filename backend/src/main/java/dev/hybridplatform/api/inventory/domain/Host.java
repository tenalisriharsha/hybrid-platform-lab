package dev.hybridplatform.api.inventory.domain;

import java.util.List;

public record Host(String id, String name, String cluster, int cpuCores, int memoryMb, List<String> datastoreIds) {

    public Host {
        if (id == null || id.isBlank()) {
            throw new IllegalArgumentException("Host id must not be blank");
        }
        datastoreIds = datastoreIds == null ? List.of() : List.copyOf(datastoreIds);
    }
}
