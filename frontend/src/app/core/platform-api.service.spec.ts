import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { PlatformApiService } from './platform-api.service';
import { Datastore, Host, InventorySummary, VirtualMachine } from './models/inventory';

describe('PlatformApiService', () => {
  let service: PlatformApiService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(PlatformApiService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('fetches the inventory summary from /api/v1/summary', () => {
    const payload: InventorySummary = {
      hostCount: 2,
      vmCount: 3,
      datastoreCount: 2,
      vmsPoweredOn: 2,
      vmsPoweredOff: 1,
      vmsSuspended: 0,
      totalDatastoreCapacityGb: 6144,
      totalDatastoreFreeGb: 4300,
    };

    let result: InventorySummary | undefined;
    service.getSummary().subscribe((value) => (result = value));

    const req = httpMock.expectOne('/api/v1/summary');
    expect(req.request.method).toBe('GET');
    req.flush(payload);

    expect(result).toEqual(payload);
  });

  it('fetches hosts from /api/v1/hosts', () => {
    const payload: Host[] = [
      { id: 'host-1', name: 'esx-1', cluster: 'lab-cluster', cpuCores: 16, memoryMb: 131072, datastoreIds: ['ds-1'] },
    ];

    let result: Host[] | undefined;
    service.getHosts().subscribe((value) => (result = value));

    const req = httpMock.expectOne('/api/v1/hosts');
    expect(req.request.method).toBe('GET');
    req.flush(payload);

    expect(result).toEqual(payload);
  });

  it('fetches VMs from /api/v1/vms', () => {
    const payload: VirtualMachine[] = [
      { id: 'vm-1', name: 'web-01', hostId: 'host-1', powerState: 'POWERED_ON', cpuCount: 2, memoryMb: 4096 },
    ];

    let result: VirtualMachine[] | undefined;
    service.getVms().subscribe((value) => (result = value));

    const req = httpMock.expectOne('/api/v1/vms');
    expect(req.request.method).toBe('GET');
    req.flush(payload);

    expect(result).toEqual(payload);
  });

  it('fetches datastores from /api/v1/datastores', () => {
    const payload: Datastore[] = [{ id: 'ds-1', name: 'datastore-1', capacityGb: 2048, freeGb: 1024 }];

    let result: Datastore[] | undefined;
    service.getDatastores().subscribe((value) => (result = value));

    const req = httpMock.expectOne('/api/v1/datastores');
    expect(req.request.method).toBe('GET');
    req.flush(payload);

    expect(result).toEqual(payload);
  });

  it('posts a power state change to /api/v1/vms/{id}/power', () => {
    const updated: VirtualMachine = {
      id: 'vm-1',
      name: 'web-01',
      hostId: 'host-1',
      powerState: 'POWERED_OFF',
      cpuCount: 2,
      memoryMb: 4096,
    };

    let result: VirtualMachine | undefined;
    service.setVmPower('vm-1', 'POWERED_OFF').subscribe((value) => (result = value));

    const req = httpMock.expectOne('/api/v1/vms/vm-1/power');
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual({ state: 'POWERED_OFF' });
    req.flush(updated);

    expect(result).toEqual(updated);
  });

  it('fetches health from /actuator/health', () => {
    let result: { status: string } | undefined;
    service.getHealth().subscribe((value) => (result = value));

    const req = httpMock.expectOne('/actuator/health');
    expect(req.request.method).toBe('GET');
    req.flush({ status: 'UP' });

    expect(result).toEqual({ status: 'UP' });
  });
});
