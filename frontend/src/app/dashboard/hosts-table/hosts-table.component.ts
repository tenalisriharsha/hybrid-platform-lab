import { DecimalPipe } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { PlatformApiService } from '../../core/platform-api.service';
import { Host } from '../../core/models/inventory';

@Component({
  selector: 'app-hosts-table',
  standalone: true,
  imports: [DecimalPipe],
  templateUrl: './hosts-table.component.html',
})
export class HostsTableComponent implements OnInit {
  private readonly api = inject(PlatformApiService);

  hosts: Host[] | null = null;
  error = false;

  ngOnInit(): void {
    this.api.getHosts().subscribe({
      next: (hosts) => (this.hosts = hosts),
      error: () => (this.error = true),
    });
  }
}
