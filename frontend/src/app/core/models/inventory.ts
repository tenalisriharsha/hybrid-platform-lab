export type PowerState = 'POWERED_ON' | 'POWERED_OFF' | 'SUSPENDED';

export interface Host {
  id: string;
  name: string;
  cluster: string;
  cpuCores: number;
  memoryMb: number;
  datastoreIds: string[];
}

export interface VirtualMachine {
  id: string;
  name: string;
  hostId: string;
  powerState: PowerState;
  cpuCount: number;
  memoryMb: number;
}

export interface Datastore {
  id: string;
  name: string;
  capacityGb: number;
  freeGb: number;
}

export interface InventorySummary {
  hostCount: number;
  vmCount: number;
  datastoreCount: number;
  vmsPoweredOn: number;
  vmsPoweredOff: number;
  vmsSuspended: number;
  totalDatastoreCapacityGb: number;
  totalDatastoreFreeGb: number;
}

export interface HealthResponse {
  status: 'UP' | 'DOWN' | 'OUT_OF_SERVICE' | 'UNKNOWN';
}
