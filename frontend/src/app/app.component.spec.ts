import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed, discardPeriodicTasks, fakeAsync, tick } from '@angular/core/testing';
import { AppComponent } from './app.component';

describe('AppComponent', () => {
  let httpMock: HttpTestingController;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AppComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    }).compileComponents();

    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  function createAndRender() {
    const fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();

    // HostsTableComponent subscribes directly, so its request fires
    // synchronously; SummaryPanelComponent polls via timer(0, ...), which is
    // scheduled as a macrotask and only fires once the fakeAsync clock ticks.
    httpMock.expectOne('/api/v1/hosts').flush([]);
    tick();
    httpMock.expectOne('/api/v1/summary').flush({
      hostCount: 2,
      vmCount: 3,
      datastoreCount: 2,
      vmsPoweredOn: 2,
      vmsPoweredOff: 1,
      vmsSuspended: 0,
      totalDatastoreCapacityGb: 6144,
      totalDatastoreFreeGb: 4300,
    });
    httpMock.expectOne('/actuator/health').flush({ status: 'UP' });
    fixture.detectChanges();
    return fixture;
  }

  it('creates the app and titles it Hybrid Platform Lab', fakeAsync(() => {
    const fixture = createAndRender();
    const app = fixture.componentInstance;
    expect(app).toBeTruthy();
    expect(app.title).toEqual('Hybrid Platform Lab');

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('h1')?.textContent).toContain('Hybrid Platform Lab');
    discardPeriodicTasks();
  }));

  it('defaults to the hosts tab and switches tabs on click', fakeAsync(() => {
    const fixture = createAndRender();
    const compiled = fixture.nativeElement as HTMLElement;

    expect(fixture.componentInstance.activeTab).toBe('hosts');

    const vmsTabButton = Array.from(compiled.querySelectorAll('button[role="tab"]')).find((button) =>
      button.textContent?.includes('Virtual machines'),
    ) as HTMLButtonElement;
    vmsTabButton.click();
    fixture.detectChanges();

    httpMock.expectOne('/api/v1/vms').flush([]);

    expect(fixture.componentInstance.activeTab).toBe('vms');
    discardPeriodicTasks();
  }));
});
