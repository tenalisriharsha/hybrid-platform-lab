package dev.hybridplatform.api.inventory;

import java.time.Instant;

/** Summary returned after an inventory sync replaces the in-memory estate. */
public record SyncResult(int hostCount, int vmCount, int datastoreCount, Instant syncedAt) {}
