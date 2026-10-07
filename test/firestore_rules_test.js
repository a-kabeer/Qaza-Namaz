#!/usr/bin/env node

const { readFileSync } = await import('node:fs');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = await import('@firebase/rules-unit-testing');
const {
  doc,
  setDoc,
  Timestamp,
} = await import('firebase/firestore');

const PROJECT = 'qaza-nmz';
const FIRESTORE_HOST = '127.0.0.1';
const FIRESTORE_PORT = 8080;
const UID = 'schema-test-user';

function rootFields() {
  return {
    schemaVersion: 1,
    cloudGeneration: 1,
    datasetState: 'ready',
    updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
    bootstrapComplete: true,
  };
}

function validPayload(overrides = {}) {
  return {
    id: 'record-1',
    userId: UID,
    prayerType: 'fajr',
    status: 'pending',
    originalDate: Timestamp.fromDate(new Date('2025-12-31T00:00:00Z')),
    createdAt: Timestamp.fromDate(new Date('2025-12-31T00:00:00Z')),
    updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
    recordVersion: 1,
    completedAt: null,
    completionId: null,
    additionId: null,
    profilePlanRevisionId: null,
    profilePlanFingerprint: null,
    ...overrides,
  };
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: {
      host: FIRESTORE_HOST,
      port: FIRESTORE_PORT,
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });

  try {
    const context = testEnv.authenticatedContext(UID);
    const db = context.firestore();
    const root = doc(db, 'users', UID);
    const record = doc(db, 'users', UID, 'qazaRecords', 'record-1');

    await assertSucceeds(setDoc(root, rootFields()));
    await assertSucceeds(setDoc(record, {
      schemaVersion: 1,
      cloudGeneration: 1,
      entityVersion: 1,
      updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      writerDeviceId: 'device-schema-test',
      operationId: 'op-schema-test',
      payload: validPayload(),
    }));

    await assertFails(setDoc(doc(db, 'users', UID, 'qazaRecords', 'missing-user-id'), {
      schemaVersion: 1,
      cloudGeneration: 1,
      entityVersion: 1,
      updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      writerDeviceId: 'device-schema-test',
      operationId: 'op-missing-user-id',
      payload: (() => {
        const payload = validPayload({ id: 'missing-user-id' });
        delete payload.userId;
        return payload;
      })(),
    }));

    await assertFails(setDoc(doc(db, 'users', UID, 'qazaRecords', 'bad-prayer'), {
      schemaVersion: 1,
      cloudGeneration: 1,
      entityVersion: 1,
      updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      writerDeviceId: 'device-schema-test',
      operationId: 'op-bad-prayer',
      payload: validPayload({ id: 'bad-prayer', prayerType: 'dhuhr' }),
    }));

    await assertFails(setDoc(doc(db, 'users', UID, 'qazaRecords', 'bad-status'), {
      schemaVersion: 1,
      cloudGeneration: 1,
      entityVersion: 1,
      updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      writerDeviceId: 'device-schema-test',
      operationId: 'op-bad-status',
      payload: validPayload({ id: 'bad-status', status: 'done' }),
    }));

    await assertFails(setDoc(doc(db, 'users', UID, 'qazaRecords', 'bad-date'), {
      schemaVersion: 1,
      cloudGeneration: 1,
      entityVersion: 1,
      updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      writerDeviceId: 'device-schema-test',
      operationId: 'op-bad-date',
      payload: validPayload({
        id: 'bad-date',
        originalDate: '2025-12-31',
      }),
    }));

    await assertFails(setDoc(doc(db, 'users', UID, 'qazaRecords', 'extra-key'), {
      schemaVersion: 1,
      cloudGeneration: 1,
      entityVersion: 1,
      updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      writerDeviceId: 'device-schema-test',
      operationId: 'op-extra-key',
      payload: validPayload({
        id: 'extra-key',
        unexpected: true,
      }),
    }));

    console.log('Firestore Qaza payload schema tests passed.');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
