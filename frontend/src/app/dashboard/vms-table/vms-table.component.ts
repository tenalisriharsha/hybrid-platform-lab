import { DecimalPipe } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { PlatformApiService } from '../../core/platform-api.service';
import { PowerState, VirtualMachine } from '../../core/models/inventory';
import { BadgeStatus, StatusBadgeComponent } from '../../shared/status-badge/status-badge.component';

@Component({
  selector: 'app-vms-table',
  standalone: true,
  imports: [DecimalPipe, StatusBadgeComponent],
  templateUrl: './vms-table.component.html',
})
export class VmsTableComponent implements OnInit {
  private readonly api = inject(PlatformApiService);

  vms: VirtualMachine[] | null = null;
  error = false;
  pendingVmId: string | null = null;

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.api.getVms().subscribe({
      next: (vms) => (this.vms = vms),
      error: () => (this.error = true),
    });
  }

  powerBadge(state: PowerState): { status: BadgeStatus; label: string } {
    switch (state) {
      case 'POWERED_ON':
        return { status: 'good', label: 'Powered on' };
      case 'POWERED_OFF':
        return { status: 'muted', label: 'Powered off' };
      case 'SUSPENDED':
        return { status: 'warning', label: 'Suspended' };
    }
  }

  togglePower(vm: VirtualMachine): void {
    const nextState: PowerState = vm.powerState === 'POWERED_ON' ? 'POWERED_OFF' : 'POWERED_ON';
    this.pendingVmId = vm.id;
    this.api.setVmPower(vm.id, nextState).subscribe({
      next: (updated) => {
        this.vms = (this.vms ?? []).map((existing) => (existing.id === updated.id ? updated : existing));
        this.pendingVmId = null;
      },
      error: () => {
        this.pendingVmId = null;
      },
    });
  }
}
