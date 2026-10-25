import { ComponentFixture, TestBed } from '@angular/core/testing';
import { StatusBadgeComponent } from './status-badge.component';

describe('StatusBadgeComponent', () => {
  let fixture: ComponentFixture<StatusBadgeComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [StatusBadgeComponent] });
    fixture = TestBed.createComponent(StatusBadgeComponent);
  });

  it('renders the label and a status-specific class', () => {
    fixture.componentRef.setInput('status', 'good');
    fixture.componentRef.setInput('label', 'Healthy');
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    const badge = compiled.querySelector('.badge');
    expect(badge?.textContent).toContain('Healthy');
    expect(badge?.classList.contains('badge--good')).toBeTrue();
  });

  it('switches the status class when the status changes', () => {
    fixture.componentRef.setInput('status', 'critical');
    fixture.componentRef.setInput('label', 'Unreachable');
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.badge')?.classList.contains('badge--critical')).toBeTrue();
  });
});
