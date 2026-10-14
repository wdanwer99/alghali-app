// POST /functions/v1/booking-slots
// Body: { items, place: "BAY" | "CUSTOMER_LOCATION", address_id?, lat?, lng?, variant_id?, technician_id? }
// The slot engine (PLAN §5): reads booking_context() as the caller (guests too, with the
// anon key) and returns each suitable technician with their price, score and next free
// start, plus "any available" — or, with technician_id, that technician's every start.
// The hold itself is create_booking_hold(), which checks everything again in the
// database (D-096).
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { bookingOptions, type BookingContext } from '../_shared/slots/options.ts';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

const uuidOrNull = (v: unknown) => (typeof v === 'string' && UUID.test(v) ? v : null);
const numberOrNull = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : null);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return reply(405, { error: 'METHOD_NOT_ALLOWED' });

  const apikey = req.headers.get('apikey') ?? Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  // A signed-in buyer's token is passed on; guests go as the anon role.
  const authorization = req.headers.get('Authorization') ?? '';
  const userJwt = /^Bearer [\w-]+\.[\w-]+\.[\w-]+$/.test(authorization) ? authorization : null;

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return reply(400, { error: 'INVALID_BODY' });
  }
  const place = body.place;
  if ((place !== 'BAY' && place !== 'CUSTOMER_LOCATION') || !Array.isArray(body.items)) {
    return reply(400, { error: 'INVALID_BODY' });
  }
  const technicianId = uuidOrNull(body.technician_id) ?? undefined;

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, apikey, {
    ...(userJwt ? { global: { headers: { Authorization: userJwt } } } : {}),
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await supabase.rpc('booking_context', {
    p_items: body.items,
    p_place: place,
    p_address_id: uuidOrNull(body.address_id),
    p_lat: numberOrNull(body.lat),
    p_lng: numberOrNull(body.lng),
    p_variant_id: uuidOrNull(body.variant_id),
    p_technician_id: technicianId ?? null,
  });
  if (error) {
    const status = error.code === 'P0002' ? 404 : error.code === '42501' ? 403 : 400;
    return reply(status, {
      error: /^[A-Z][A-Z0-9_]+$/.test(error.message) ? error.message : 'BAD_REQUEST',
    });
  }
  return reply(200, bookingOptions(data as BookingContext, place, technicianId));
});
