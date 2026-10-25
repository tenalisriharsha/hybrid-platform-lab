import { expect, test } from '@playwright/test';

// Requires a running platform-api on localhost:8080 and `ng serve --proxy-config
// proxy.conf.json` on localhost:4200 (see frontend/README.md).

test('dashboard loads real inventory and health from platform-api', async ({ page }) => {
  await page.goto('/');

  await expect(page.locator('h1')).toHaveText('Hybrid Platform Lab');
  await expect(page.getByText('Healthy')).toBeVisible();

  const hostsTile = page.locator('app-stat-tile').filter({ hasText: 'Hosts' });
  await expect(hostsTile.locator('.tile__value')).not.toHaveText('');

  await expect(page.locator('app-hosts-table table')).toBeVisible();
  await expect(page.locator('app-hosts-table tbody tr').first()).toBeVisible();
});

test('switching tabs loads VMs and datastores', async ({ page }) => {
  await page.goto('/');

  await page.getByRole('tab', { name: 'Virtual machines' }).click();
  await expect(page.locator('app-vms-table table')).toBeVisible();
  await expect(page.locator('app-vms-table tbody tr').first()).toBeVisible();

  await page.getByRole('tab', { name: 'Datastores' }).click();
  await expect(page.locator('app-datastores-table table')).toBeVisible();
  await expect(page.locator('app-datastores-table tbody tr').first()).toBeVisible();
});

test('toggling a VM power state calls the API and updates the row', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('tab', { name: 'Virtual machines' }).click();

  const firstRow = page.locator('app-vms-table tbody tr').first();
  const button = firstRow.locator('button');
  const originalLabel = await button.textContent();

  await button.click();
  await expect(button).not.toHaveText(originalLabel ?? '');
});
