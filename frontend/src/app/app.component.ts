import { Component } from '@angular/core';
import { DatastoresTableComponent } from './dashboard/datastores-table/datastores-table.component';
import { HostsTableComponent } from './dashboard/hosts-table/hosts-table.component';
import { SummaryPanelComponent } from './dashboard/summary-panel/summary-panel.component';
import { VmsTableComponent } from './dashboard/vms-table/vms-table.component';

type InventoryTab = 'hosts' | 'vms' | 'datastores';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [SummaryPanelComponent, HostsTableComponent, VmsTableComponent, DatastoresTableComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css',
})
export class AppComponent {
  readonly title = 'Hybrid Platform Lab';

  activeTab: InventoryTab = 'hosts';

  selectTab(tab: InventoryTab): void {
    this.activeTab = tab;
  }
}
