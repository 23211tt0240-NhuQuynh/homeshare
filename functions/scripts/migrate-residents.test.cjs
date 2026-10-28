const {test} = require('node:test');
const assert = require('node:assert/strict');
const {planMigration} = require('./migrate-residents.cjs');
const base = () => ({rooms: [{id: 'room', hostId: 'host', propertyId: 'home', status: 'occupied', tenantName: 'An', tenantPhone: '0912345678'}],
  posts: [], periods: [], residents: [], bookings: [{id: 'booking', hostId: 'host', roomId: 'room', renterId: 'uid', renterName: 'An', renterPhone: '0912345678', status: 'dangO'}]});
test('Backfills residents and period before deleting legacy room fields', () => {
  const result = planMigration(base(), 'now');
  assert.equal(result.skipped.length, 0);
  assert.equal(result.plans[0].changes.find(c => c.collection === 'residents').data.userId, 'uid');
  assert.deepEqual(result.plans[0].deleteFields, ['tenantName', 'tenantPhone']);
});
test('Existing residents are reused and listing IDs map to the original room', () => {
  const data = base();
  data.posts = [{id: 'post', roomId: 'room'}];
  data.rooms[0].tenantIds = ['uid', 'mate'];
  data.rooms[0].roommates = ['Bình'];
  data.rooms[0].tenantName = 'An & Bình';
  data.periods = [{id: 'period', roomId: 'post', status: 'dangO'}];
  data.residents = [{id: 'r1', userId: 'uid', fullName: 'An', roomId: 'post', periodId: 'period', statusId: 'dangO'},
    {id: 'r2', userId: 'mate', fullName: 'Bình', roomId: 'post', periodId: 'period', formId: 'oGhep', statusId: 'dangO'}];
  const result = planMigration(data, 'now');
  assert.equal(result.skipped.length, 0);
  assert.deepEqual(result.plans[0].changes.filter(c => c.collection === 'residents').map(c => c.id), ['r1', 'r2']);
  assert.ok(result.plans[0].changes.every(c => c.data.roomId === 'room'));
});
test('Unresolved roommates block deletion; planner never invents an identity', () => {
  const data = base(); data.rooms[0].roommates = ['Unknown'];
  assert.equal(planMigration(data, 'now').plans.length, 0);
});
test('Already migrated rooms have no writes and no legacy data is recreated', () => {
  const data = base(); delete data.rooms[0].tenantName; delete data.rooms[0].tenantPhone;
  assert.equal(planMigration(data, 'now').plans.length, 0);
});
