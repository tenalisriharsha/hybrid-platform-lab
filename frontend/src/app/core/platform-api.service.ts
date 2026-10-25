import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import {
  Datastore,
  HealthResponse,
  Host,
  InventorySummary,
  PowerState,
  VirtualMachine,
} from './models/inventory';

@Injectable({ providedIn: 'root' })
export class PlatformApiService {
  constructor(private readonly http: HttpClient) {}

  getSummary(): Observable<InventorySummary> {
    return this.http.get<InventorySummary>('/api/v1/summary');
  }

  getHosts(): Observable<Host[]> {
    return this.http.get<Host[]>('/api/v1/hosts');
  }

  getVms(): Observable<VirtualMachine[]> {
    return this.http.get<VirtualMachine[]>('/api/v1/vms');
  }

  getDatastores(): Observable<Datastore[]> {
    return this.http.get<Datastore[]>('/api/v1/datastores');
  }

  setVmPower(id: string, state: PowerState): Observable<VirtualMachine> {
    return this.http.post<VirtualMachine>(`/api/v1/vms/${id}/power`, { state });
  }

  getHealth(): Observable<HealthResponse> {
    return this.http.get<HealthResponse>('/actuator/health');
  }
}
