import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { DatastoresTableComponent } from './datastores-table.component';
import { Datastore } from '../../core/models/inventory';

describe('DatastoresTableComponent', () => {
  let fixture: ComponentFixture<DatastoresTableComponent>;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [DatastoresTableComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    fixture = TestBed.createComponent(DatastoresTableComponent);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('shows a loading state before datastores arrive', () => {
    fixture.detectChanges();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.panel__loading')?.textContent).toContain('Loading datastores');
    httpMock.expectOne('/api/v1/datastores');
  });

  it('renders a row per datastore with a computed usage percentage', () => {
    fixture.detectChanges();

    const datastores: Datastore[] = [
      { id: 'ds-1', name: 'datastore-1', capacityGb: 2000, freeGb: 500 },
      { id: 'ds-2', name: 'datastore-2', capacityGb: 0, freeGb: 0 },
    ];
    httpMock.expectOne('/api/v1/datastores').flush(datastores);
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    const rows = compiled.querySelectorAll('tbody tr');
    expect(rows.length).toBe(2);
    expect(rows[0].textContent).toContain('datastore-1');
    expect(rows[0].textContent).toContain('75%');
    expect(rows[1].textContent).toContain('0%');
  });

  it('shows an empty-state row when there are no datastores', () => {
    fixture.detectChanges();
    httpMock.expectOne('/api/v1/datastores').flush([]);
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('tbody')?.textContent).toContain('No datastores in inventory');
  });

  it('shows an error state when the request fails', () => {
    fixture.detectChanges();
    httpMock.expectOne('/api/v1/datastores').flush('boom', { status: 500, statusText: 'Server Error' });
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.panel__error')?.textContent).toContain('Could not load datastores');
  });
});
