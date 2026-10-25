import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { VmsTableComponent } from './vms-table.component';
import { VirtualMachine } from '../../core/models/inventory';

describe('VmsTableComponent', () => {
  let fixture: ComponentFixture<VmsTableComponent>;
  let httpMock: HttpTestingController;

  const vms: VirtualMachine[] = [
    { id: 'vm-1', name: 'web-01', hostId: 'host-1', powerState: 'POWERED_ON', cpuCount: 2, memoryMb: 4096 },
    { id: 'vm-2', name: 'db-01', hostId: 'host-1', powerState: 'POWERED_OFF', cpuCount: 4, memoryMb: 8192 },
    { id: 'vm-3', name: 'queue-01', hostId: 'host-2', powerState: 'SUSPENDED', cpuCount: 1, memoryMb: 2048 },
  ];

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [VmsTableComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    fixture = TestBed.createComponent(VmsTableComponent);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  function loadVms() {
    fixture.detectChanges();
    httpMock.expectOne('/api/v1/vms').flush(vms);
    fixture.detectChanges();
  }

  it('shows a loading state before VMs arrive', () => {
    fixture.detectChanges();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.panel__loading')?.textContent).toContain('Loading VMs');
    httpMock.expectOne('/api/v1/vms');
  });

  it('renders a row per VM with a power badge', () => {
    loadVms();
    const compiled = fixture.nativeElement as HTMLElement;
    const rows = compiled.querySelectorAll('tbody tr');
    expect(rows.length).toBe(3);
    expect(rows[0].textContent).toContain('web-01');
    expect(rows[0].textContent).toContain('Powered on');
    expect(rows[1].textContent).toContain('Powered off');
    expect(rows[2].textContent).toContain('Suspended');
  });

  it('disables the power button for a suspended VM', () => {
    loadVms();
    const compiled = fixture.nativeElement as HTMLElement;
    const rows = compiled.querySelectorAll('tbody tr');
    const suspendedButton = rows[2].querySelector('button') as HTMLButtonElement;
    expect(suspendedButton.disabled).toBeTrue();
  });

  it('powers off a running VM and updates the row in place', () => {
    loadVms();
    const compiled = fixture.nativeElement as HTMLElement;
    const rows = compiled.querySelectorAll('tbody tr');
    const powerButton = rows[0].querySelector('button') as HTMLButtonElement;
    expect(powerButton.textContent).toContain('Power off');

    powerButton.click();
    fixture.detectChanges();
    expect(powerButton.disabled).toBeTrue();

    const req = httpMock.expectOne('/api/v1/vms/vm-1/power');
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual({ state: 'POWERED_OFF' });
    req.flush({ ...vms[0], powerState: 'POWERED_OFF' });
    fixture.detectChanges();

    const updatedRow = compiled.querySelectorAll('tbody tr')[0];
    expect(updatedRow.textContent).toContain('Powered off');
    expect((updatedRow.querySelector('button') as HTMLButtonElement).disabled).toBeFalse();
  });

  it('shows an empty-state row when there are no VMs', () => {
    fixture.detectChanges();
    httpMock.expectOne('/api/v1/vms').flush([]);
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('tbody')?.textContent).toContain('No virtual machines in inventory');
  });

  it('shows an error state when the request fails', () => {
    fixture.detectChanges();
    httpMock.expectOne('/api/v1/vms').flush('boom', { status: 500, statusText: 'Server Error' });
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.panel__error')?.textContent).toContain('Could not load VMs');
  });
});
