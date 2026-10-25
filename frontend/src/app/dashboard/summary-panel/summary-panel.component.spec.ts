import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ComponentFixture, TestBed, discardPeriodicTasks, fakeAsync, tick } from '@angular/core/testing';
import { SummaryPanelComponent } from './summary-panel.component';

describe('SummaryPanelComponent', () => {
  let fixture: ComponentFixture<SummaryPanelComponent>;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [SummaryPanelComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    fixture = TestBed.createComponent(SummaryPanelComponent);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('shows a loading state before the summary and health responses arrive', fakeAsync(() => {
    fixture.detectChanges();
    tick();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.panel__loading')?.textContent).toContain('Loading summary');
    expect(compiled.textContent).toContain('Checking…');

    httpMock.expectOne('/api/v1/summary');
    httpMock.expectOne('/actuator/health');
    discardPeriodicTasks();
  }));

  it('renders stat tiles and a healthy badge once both calls succeed', fakeAsync(() => {
    fixture.detectChanges();
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

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('Healthy');
    expect(compiled.querySelectorAll('app-stat-tile').length).toBe(4);

    tick(15_000);
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
    discardPeriodicTasks();
  }));

  it('shows an error state and an unreachable badge when the calls fail', fakeAsync(() => {
    fixture.detectChanges();
    tick();

    httpMock.expectOne('/api/v1/summary').flush('boom', { status: 500, statusText: 'Server Error' });
    httpMock.expectOne('/actuator/health').flush('boom', { status: 500, statusText: 'Server Error' });
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.panel__error')?.textContent).toContain('Could not load the inventory summary');
    expect(compiled.textContent).toContain('Unreachable');
    discardPeriodicTasks();
  }));
});
