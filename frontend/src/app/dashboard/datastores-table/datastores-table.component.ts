import { DecimalPipe } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { PlatformApiService } from '../../core/platform-api.service';
import { Datastore } from '../../core/models/inventory';

@Component({
  selector: 'app-datastores-table',
  standalone: true,
  imports: [DecimalPipe],
  templateUrl: './datastores-table.component.html',
  styleUrl: './datastores-table.component.css',
})
export class DatastoresTableComponent implements OnInit {
  private readonly api = inject(PlatformApiService);

  datastores: Datastore[] | null = null;
  error = false;

  ngOnInit(): void {
    this.api.getDatastores().subscribe({
      next: (datastores) => (this.datastores = datastores),
      error: () => (this.error = true),
    });
  }

  usedPercent(datastore: Datastore): number {
    if (datastore.capacityGb === 0) {
      return 0;
    }
    const used = datastore.capacityGb - datastore.freeGb;
    return Math.round((used / datastore.capacityGb) * 100);
  }
}
