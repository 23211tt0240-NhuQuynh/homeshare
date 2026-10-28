// Dry-run by default. Uses Application Default Credentials only in the CLI.
// Never removes a legacy occupant field unless every identified occupant has
// a residents row in the same atomic batch. Unresolved rooms are skipped.
const LEGACY = ['tenantName', 'tenantPhone', 'tenantAvatar', 'tenantIds', 'roommates'];
const active = d => !d.moveOutDate && ['dango', 'active'].includes(String(d.statusId || d.status || '').toLowerCase());
const checkedIn = d => !['cancelled', 'rejected', 'dahuy', 'checked_out'].includes(String(d.status || '').toLowerCase()) &&
  (['dango', 'active', 'danhanphong'].includes(String(d.status || '').toLowerCase()) || d.isCheckIn === true || d.daNhanPhong === true);
const pick = (d, keys) => keys.map(k => d[k]).find(v => typeof v === 'string' && v.trim()) || '';
function planMigration({rooms, posts, bookings, periods, residents}, now) {
  const roomMap = new Map(rooms.map(d => [d.id, d]));
  const postMap = new Map(posts.map(d => [d.id, d]));
  const canonical = id => {
    const post = postMap.get(id);
    return post ? pick(post, ['roomId', 'room_id', 'phongId', 'phong_tro_id']) || id : id;
  };
  const plans = [], skipped = [];
  // Process both real rooms and phantom documents previously written by post ID.
  for (const source of rooms.filter(d => LEGACY.some(k => k in d))) {
    const roomId = canonical(source.id);
    const room = roomMap.get(roomId);
    if (!room || !room.hostId || !room.propertyId) {
      skipped.push({roomId: source.id, reason: 'Cannot verify original room and host'}); continue;
    }
    const currentBookings = bookings.filter(b => checkedIn(b) && canonical(pick(b, ['roomId', 'phongId'])) === roomId &&
      pick(b, ['hostId', 'chuNhaId']) === room.hostId);
    const rows = residents.filter(r => active(r) && canonical(r.roomId ||
      periods.find(p => p.id === (r.periodId || r.kyThue_id))?.roomId) === roomId);
    const ids = new Set([...(source.tenantIds || []), ...rows.map(r => r.userId),
      ...currentBookings.map(b => pick(b, ['renterId', 'nguoiDungId', 'nguoiDung_Id']))].filter(Boolean));
    if (!ids.size || ['available', 'deleted'].includes(room.status)) {
      skipped.push({roomId: source.id, reason: 'No verified current occupant, or room not occupied'}); continue;
    }
    const changes = [];
    let valid = true;
    for (const userId of ids) {
      const row = rows.find(r => r.userId === userId);
      const booking = currentBookings.find(b => pick(b, ['renterId', 'nguoiDungId', 'nguoiDung_Id']) === userId);
      if (row) {
        const patch = {roomId};
        if (!row.phone && booking) patch.phone = pick(booking, ['renterPhone', 'sdtNguoiO']);
        changes.push({collection: 'residents', id: row.id, data: patch});
        const periodId = row.periodId || row.kyThue_id;
        if (periodId && periods.some(p => p.id === periodId)) changes.push({collection: 'periods', id: periodId, data: {roomId}});
      } else if (booking) {
        const period = periods.find(p => p.bookingId === booking.id && ['dango', 'active'].includes(String(p.status).toLowerCase()));
        const periodId = period?.id || `checkin_${booking.id}`;
        const start = booking.checkedInAt || booking.checkinAt || booking.acceptedDate || source.contractStart || now;
        if (!period) changes.push({collection: 'periods', id: periodId, data: {
          id: periodId, bookingId: booking.id, roomId, renterId: userId, startDate: start, status: 'dangO', createdAt: now,
        }});
        const id = `${periodId}_${userId}`;
        changes.push({collection: 'residents', id, data: {id, roomId, periodId, userId,
          fullName: pick(booking, ['renterName', 'tenNguoiO']), phone: pick(booking, ['renterPhone', 'sdtNguoiO']),
          avatar: source.tenantAvatar || '', formId: 'chinh', statusId: 'dangO', status: 'active', moveInDate: start, createdAt: now}});
      } else { valid = false; break; }
    }
    // A name/roommate list without verifiable UIDs must be reviewed, not guessed.
    const knownNames = new Set([...rows.map(r => r.fullName), ...currentBookings.map(b => pick(b, ['renterName', 'tenNguoiO']))]);
    if ((source.roommates || []).some(name => !knownNames.has(name))) valid = false;
    if (source.tenantName && !knownNames.has(source.tenantName) && !source.tenantIds?.length &&
        !rows.some(r => r.formId === 'oGhep')) valid = false;
    if (!valid || !changes.length || changes.length >= 499) {
      skipped.push({roomId: source.id, reason: 'Unresolved occupant identity or unsafe batch size'}); continue;
    }
    plans.push({sourceId: source.id, roomId, changes, deleteFields: LEGACY.filter(k => k in source)});
  }
  return {plans, skipped};
}
module.exports = {planMigration};

async function main() {
  const args = process.argv.slice(2);
  const projectIndex = args.indexOf('--project');
  const projectId = projectIndex < 0 ? '' : args[projectIndex + 1];
  if (!projectId) throw new Error('Pass --project homeshare-fe18e; optionally --apply and --backup <new-file.json>');
  const admin = require('firebase-admin');
  const fs = require('node:fs');
  admin.initializeApp({projectId, credential: admin.credential.applicationDefault()});
  const db = admin.firestore();
  const collections = ['host_rooms', 'posts', 'bookings', 'periods', 'residents'];
  const snapshots = await Promise.all(collections.map(c => db.collection(c).get()));
  const data = Object.fromEntries(snapshots.map((s, i) => [collections[i], s.docs.map(d => ({...d.data(), id: d.id}))]));
  const result = planMigration({rooms: data.host_rooms, ...data}, admin.firestore.Timestamp.now());
  console.log(JSON.stringify({mode: args.includes('--apply') ? 'apply' : 'dry-run',
    rooms: result.plans.map(p => ({sourceId: p.sourceId, roomId: p.roomId, writes: p.changes.length, deleteFields: p.deleteFields})), skipped: result.skipped}, null, 2));
  if (!args.includes('--apply')) return;
  const backupIndex = args.indexOf('--backup');
  if (backupIndex < 0 || !args[backupIndex + 1]) throw new Error('--apply requires --backup <new-file.json>');
  // Preserve a JSON snapshot for inspection before applying any deletion.
  fs.writeFileSync(args[backupIndex + 1], JSON.stringify(data, null, 2), {flag: 'wx'});
  const original = new Map(snapshots.flatMap((snapshot, i) => snapshot.docs.map(doc => [`${collections[i]}/${doc.id}`, doc])));
  for (const plan of result.plans) {
    const batch = db.batch();
    const merged = new Map();
    for (const change of plan.changes) {
      const path = `${change.collection}/${change.id}`;
      merged.set(path, {...(merged.get(path) || {}), ...change.data});
    }
    for (const [path, patch] of merged) {
      const old = original.get(path);
      if (old) batch.update(db.doc(path), patch, {lastUpdateTime: old.updateTime});
      else batch.create(db.doc(path), patch);
    }
    const source = original.get(`host_rooms/${plan.sourceId}`);
    batch.update(source.ref, Object.fromEntries(plan.deleteFields.map(k => [k, admin.firestore.FieldValue.delete()])), {lastUpdateTime: source.updateTime});
    await batch.commit();
  }
}
if (require.main === module) main().catch(error => {console.error(error.message); process.exitCode = 1;});
