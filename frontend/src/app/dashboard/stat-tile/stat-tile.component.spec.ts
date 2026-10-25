import { ComponentFixture, TestBed } from '@angular/core/testing';
import { StatTileComponent } from './stat-tile.component';

describe('StatTileComponent', () => {
  let fixture: ComponentFixture<StatTileComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [StatTileComponent] });
    fixture = TestBed.createComponent(StatTileComponent);
  });

  it('renders the label and value', () => {
    fixture.componentRef.setInput('label', 'Hosts');
    fixture.componentRef.setInput('value', 4);
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.tile__label')?.textContent).toContain('Hosts');
    expect(compiled.querySelector('.tile__value')?.textContent).toContain('4');
    expect(compiled.querySelector('.tile__sublabel')).toBeNull();
  });

  it('renders a sublabel when provided', () => {
    fixture.componentRef.setInput('label', 'VMs');
    fixture.componentRef.setInput('value', 6);
    fixture.componentRef.setInput('sublabel', '4 on · 2 off');
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.tile__sublabel')?.textContent).toContain('4 on · 2 off');
  });
});
