import { expect, test } from '@playwright/test';
import { dictionaries, openPage, writes } from './support';

/**
 * The queues' main actions, end to end in the browser. They change data, so they run only
 * against CI's throwaway stack with the demo data (E2E_WRITES=1), never against dev.
 */
test.describe('queue actions', () => {
  test.skip(!writes, 'changes data: runs only on a throwaway stack (E2E_WRITES=1)');
  const d = dictionaries.en;

  test('a technician application is approved', async ({ page }) => {
    await openPage(page, 'en', '/approvals', d.approvals.title);
    // The demo data leaves two technicians waiting.
    await page.getByRole('tab', { name: new RegExp(`^${d.approvals.technicians}`) }).click();
    const approve = page.getByRole('button', { name: d.common.approve, exact: true });
    test.skip((await approve.count()) === 0, 'no application waiting');
    const before = await approve.count();
    await approve.first().click();
    await expect(approve).toHaveCount(before - 1);
  });

  test('a partner balance is corrected', async ({ page }) => {
    await openPage(page, 'en', '/cash', d.cash.title);
    await page
      .getByRole('button', { name: new RegExp(`^${d.cash.adjust} `) })
      .first()
      .click();
    const dialog = page.getByRole('dialog');
    await dialog.getByLabel(d.cash.adjustAmount).fill('1500');
    await dialog.getByLabel(d.cash.adjustReason).fill('Browser test correction');
    await dialog.getByRole('button', { name: d.cash.adjustSave }).click();
    await expect(page.getByText(d.cash.adjusted)).toBeVisible();
    await expect(dialog).toHaveCount(0);
  });

  test('an alert is reworded and shows the new wording', async ({ page }) => {
    await openPage(page, 'en', '/alerts', d.alerts.title);
    await page.getByRole('button', { name: `${d.common.edit} ORDER_READY` }).click();
    const dialog = page.getByRole('dialog');
    const title = dialog.getByLabel(d.alerts.titleLabel).nth(1);
    await title.fill('Your part is ready');
    await dialog.getByRole('button', { name: d.common.save }).click();
    await expect(page.getByText(d.alerts.saved)).toBeVisible();
    await expect(page.getByText('Your part is ready', { exact: true })).toBeVisible();

    // A placeholder the alert doesn't have is refused before saving.
    await page.getByRole('button', { name: `${d.common.edit} ORDER_READY` }).click();
    await dialog.getByLabel(d.alerts.bodyLabel).nth(1).fill('Ready for {buyer}.');
    await expect(dialog.getByRole('alert')).toHaveText(d.errors.UNKNOWN_PLACEHOLDER);
    await expect(dialog.getByRole('button', { name: d.common.save })).toBeDisabled();
  });

  test('a Bankak receipt is confirmed from the queue', async ({ page }) => {
    await openPage(page, 'en', '/payments', d.payments.title);
    const confirm = page.getByRole('button', { name: d.payments.confirm, exact: true });
    test.skip((await confirm.count()) === 0, 'no receipt waiting');
    const txn = page.getByLabel(d.payments.txnLabel);
    if (await txn.count())
      await txn.fill(String(100000000 + Math.floor(Math.random() * 899999999)));
    await page.getByText(d.payments.tickStatement).click();
    // The demo data includes a receipt that reuses a transaction number (D-054).
    test.skip(await confirm.isDisabled(), 'the selected receipt reuses a transaction number');
    await confirm.click();
    await expect(page.getByRole('status').filter({ hasText: /./ }).first()).toBeVisible();
  });
});
