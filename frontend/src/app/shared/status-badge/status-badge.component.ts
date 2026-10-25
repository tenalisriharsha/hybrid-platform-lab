import { Component, Input } from '@angular/core';

export type BadgeStatus = 'good' | 'warning' | 'serious' | 'critical' | 'muted';

@Component({
  selector: 'app-status-badge',
  standalone: true,
  templateUrl: './status-badge.component.html',
  styleUrl: './status-badge.component.css',
})
export class StatusBadgeComponent {
  @Input({ required: true }) status!: BadgeStatus;
  @Input({ required: true }) label!: string;
}
