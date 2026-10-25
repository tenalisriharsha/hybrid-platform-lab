import { Component, DestroyRef, OnInit, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { catchError, of, switchMap, timer } from 'rxjs';
import { PlatformApiService } from '../../core/platform-api.service';
import { HealthResponse, InventorySummary } from '../../core/models/inventory';
import { StatTileComponent } from '../stat-tile/stat-tile.component';
import { BadgeStatus, StatusBadgeComponent } from '../../shared/status-badge/status-badge.component';

const REFRESH_INTERVAL_MS = 15_000;

@Component({
  selector: 'app-summary-panel',
  standalone: true,
  imports: [StatTileComponent, StatusBadgeComponent],
  templateUrl: './summary-panel.component.html',
  styleUrl: './summary-panel.component.css',
})
export class SummaryPanelComponent implements OnInit {
  private readonly api = inject(PlatformApiService);
  private readonly destroyRef = inject(DestroyRef);

  summary: InventorySummary | null = null;
  summaryError = false;

  healthStatus: HealthResponse['status'] | null = null;
  healthError = false;

  ngOnInit(): void {
    timer(0, REFRESH_INTERVAL_MS)
      .pipe(
        switchMap(() =>
          this.api.getSummary().pipe(
            catchError(() => of(null)),
          ),
        ),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((summary) => {
        this.summary = summary;
        this.summaryError = summary === null;
      });

    timer(0, REFRESH_INTERVAL_MS)
      .pipe(
        switchMap(() =>
          this.api.getHealth().pipe(
            catchError(() => of(null)),
          ),
        ),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((health) => {
        this.healthStatus = health?.status ?? null;
        this.healthError = health === null;
      });
  }

  get healthBadge(): { status: BadgeStatus; label: string } {
    if (this.healthError) {
      return { status: 'critical', label: 'Unreachable' };
    }
    if (this.healthStatus === 'UP') {
      return { status: 'good', label: 'Healthy' };
    }
    if (this.healthStatus === null) {
      return { status: 'muted', label: 'Checking…' };
    }
    return { status: 'critical', label: this.healthStatus };
  }
}
