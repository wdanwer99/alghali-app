// POST /functions/v1/inventory-import
// Body: { shop_id, file_key, dry_run?, file_name? }; optional header Idempotency-Key (uuid).
// The shop has already uploaded the sheet to the private `imports` bucket at {shop_id}/….
// Everything runs as the caller: storage RLS decides who may read the file, and
// shop_import_rows checks shop membership. No service key is used.
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
// @ts-types="../_shared/vendor/sheetjs/xlsx.d.mts"
import * as XLSX from '../_shared/vendor/sheetjs/xlsx.mjs';
import { mergeReport, parseSheet, type ImportReport } from '../_shared/inventory/parse.ts';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_BYTES = 5 * 1024 * 1024;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, apikey, content-type, idempotency-key, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return reply(405, { error: 'METHOD_NOT_ALLOWED' });

  const authorization = req.headers.get('Authorization');
  const apikey = req.headers.get('apikey') ?? Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  if (!authorization) return reply(401, { error: 'NOT_AUTHENTICATED' });

  let body: { shop_id?: unknown; file_key?: unknown; dry_run?: unknown; file_name?: unknown };
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: 'INVALID_BODY' });
  }
  const shopId = typeof body.shop_id === 'string' ? body.shop_id : '';
  const fileKey = typeof body.file_key === 'string' ? body.file_key : '';
  const idem = req.headers.get('Idempotency-Key');
  if (
    !UUID.test(shopId) ||
    !fileKey.startsWith(`${shopId}/`) ||
    (idem !== null && !UUID.test(idem))
  ) {
    return reply(400, { error: 'INVALID_BODY' });
  }

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, apikey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: user, error: userError } = await supabase.auth.getUser();
  if (userError || !user.user) return reply(401, { error: 'NOT_AUTHENTICATED' });

  const { data: file, error: fileError } = await supabase.storage.from('imports').download(fileKey);
  if (fileError || !file) return reply(404, { error: 'FILE_NOT_FOUND' });
  if (file.size > MAX_BYTES) return reply(413, { error: 'FILE_TOO_LARGE' });

  let cells: unknown[][];
  try {
    const book = XLSX.read(new Uint8Array(await file.arrayBuffer()), {
      type: 'array',
      dense: true,
    });
    const sheet = book.Sheets[book.SheetNames[0] ?? ''];
    if (!sheet) return reply(422, { error: 'EMPTY_FILE' });
    cells = XLSX.utils.sheet_to_json(sheet, {
      header: 1,
      raw: true,
      defval: null,
      blankrows: true,
    });
  } catch {
    return reply(422, { error: 'UNREADABLE_FILE' });
  }

  const parsed = parseSheet(cells);
  const fatal = parsed.issues.find((i) => i.row === 0);
  if (fatal) return reply(422, { error: fatal.code });

  const { data, error } = await supabase.rpc('shop_import_rows', {
    p_shop_id: shopId,
    p_rows: parsed.rows,
    p_dry_run: body.dry_run === true,
    p_file_name:
      typeof body.file_name === 'string' ? body.file_name.slice(0, 200) : fileKey.split('/').pop(),
    p_idem: idem,
  });
  if (error) {
    const status = error.code === '42501' ? 403 : error.code === 'P0002' ? 404 : 400;
    return reply(status, { error: error.message });
  }
  return reply(200, mergeReport(data as ImportReport, parsed.issues));
});
