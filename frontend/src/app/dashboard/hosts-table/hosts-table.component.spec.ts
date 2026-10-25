import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HostsTableComponent } from './hosts-table.component';
import { Host } from '../../core/models/inventory';

describe('HostsTableComponent', () => {
  let fixture: ComponentFixture<HostsTableComponent>;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HostsTableComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    fixture = TestBed.createComponent(HostsTableComponent);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('shows a loading state before hosts arrive', () => {
    fixture.detectChanges();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.panel__loading')?.textContent).toContain('Loading hosts');
    httpMock.expectOne('/api/v1/hosts');
  });

  it('renders a row per host once loaded', () => {
    fixture.detectChanges();

    const hosts: Host[] = [
      { id: 'host-1', name: 'esx-1', cluster: 'lab-cluster', cpuCores: 16, memoryMb: 131072, datastoreIds: ['ds-1', 'ds-2'] },
      { id: 'host-2', name: 'esx-2', cluster: 'lab-cluster', cpuCores: 32, memoryMb: 262144, datastoreIds: ['ds-1'] },
    ];
    httpMock.expectOne('/api/v1/hosts').flush(hosts);
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    const rows = compiled.querySelectorAll('tbody tr');
    expect(rows.length).toBe(2);
    expect(rows[0].textContent).toContain('esx-1');
    expect(rows[0].textContent).toContain('lab-cluster');
    expect(rows[1].textContent).toContain('esx-2');
  });

  it('shows an empty-state row when there are no hosts', () => {
    fixture.detectChanges();
    httpMock.expectOne('/api/v1/hosts').flush([]);
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('tbody')?.textContent).toContain('No hosts in inventory');
  });

  it('shows an error state when the request fails', () => {
    fixture.detectChanges();
    httpMock.expectOne('/api/v1/hosts').flush('boom', { status: 500, statusText: 'Server Error' });
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.panel__error')?.textContent).toContain('Could not load hosts');
  });
});
