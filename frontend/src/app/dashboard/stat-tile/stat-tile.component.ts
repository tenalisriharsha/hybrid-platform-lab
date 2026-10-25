import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-stat-tile',
  standalone: true,
  templateUrl: './stat-tile.component.html',
  styleUrl: './stat-tile.component.css',
})
export class StatTileComponent {
  @Input({ required: true }) label!: string;
  @Input({ required: true }) value!: string | number;
  @Input() sublabel?: string;
}
