import {
  SampleBanner,
  Num,
  PageHeader,
  Panel,
  StatusBadge,
  Table,
  Td,
  Th,
} from '@/components/admin/ui';
import { getDictionary } from '@/i18n/dictionaries';
import { DEMO_NOW, disputes, type DisputeRow } from '@/lib/demo/data';
import { ago, formatRef } from '@/lib/format';
import { disputeTone } from '@/lib/tones';

const order: Record<DisputeRow['status'], number> = { open: 0, investigating: 1, resolved: 2 };

export default async function DisputesPage() {
  const d = await getDictionary();
  const rows = [...disputes].sort(
    (a, b) => order[a.status] - order[b.status] || b.openedAt.getTime() - a.openedAt.getTime(),
  );
  return (
    <>
      <PageHeader title={d.disputes.title} description={d.disputes.subtitle} />
      <SampleBanner title={d.sample.title} body={d.sample.disputes} />
      <Panel>
        <Table>
          <thead>
            <tr>
              <Th>{d.disputes.type}</Th>
              <Th>{d.disputes.openedBy}</Th>
              <Th>{d.disputes.related}</Th>
              <Th>{d.disputes.openedAt}</Th>
              <Th>{d.common.status}</Th>
            </tr>
          </thead>
          <tbody>
            {rows.map((x) => (
              <tr key={x.id} className="hover:bg-muted/40">
                <Td className="font-medium whitespace-nowrap">{d.disputes[x.type]}</Td>
                <Td>
                  <bdi>{x.openedBy}</bdi>
                </Td>
                <Td>
                  <Num>{formatRef(x.related)}</Num>
                </Td>
                <Td className="whitespace-nowrap text-muted-foreground">
                  {ago(x.openedAt, DEMO_NOW, d.common)}
                </Td>
                <Td>
                  <StatusBadge tone={disputeTone[x.status]}>
                    {d.status.dispute[x.status]}
                  </StatusBadge>
                </Td>
              </tr>
            ))}
          </tbody>
        </Table>
      </Panel>
    </>
  );
}
