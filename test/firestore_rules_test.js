#!/usr/bin/env node

async function main() {
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
      datasetState: 'empty',
      updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      bootstrapComplete: false,
    };
  }

  function readyRootFields() {
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
    await assertSucceeds(setDoc(root, {
      ...rootFields(),
      datasetState: 'initializing',
    }));
    await assertSucceeds(setDoc(root, readyRootFields()));
    await assertSucceeds(setDoc(record, {
      schemaVersion: 1,
      cloudGeneration: 1,
      entityVersion: 1,
      updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      writerDeviceId: 'device-schema-test',
      operationId: 'op-schema-test',
      payload: validPayload(),
    }));

    const invalidCases = [
      ['missing-user-id', (() => {
        const payload = validPayload({ id: 'missing-user-id' });
        delete payload.userId;
        return payload;
      })()],
      ['bad-prayer', validPayload({ id: 'bad-prayer', prayerType: 'dhuhr' })],
      ['bad-status', validPayload({ id: 'bad-status', status: 'done' })],
      ['bad-date', validPayload({
        id: 'bad-date',
        originalDate: '2025-12-31',
      })],
      ['extra-key', validPayload({
        id: 'extra-key',
        unexpected: true,
      })],
      ['wrong-record-id', validPayload({
        id: 'different-record-id',
      })],
    ];

    for (const [id, payload] of invalidCases) {
      await assertFails(setDoc(
        doc(db, 'users', UID, 'qazaRecords', id),
        {
          schemaVersion: 1,
          cloudGeneration: 1,
          entityVersion: 1,
          updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
          writerDeviceId: 'device-schema-test',
          operationId: 'op-' + id,
          payload,
        },
      ));
    }

    console.log('Firestore Qaza payload schema tests passed.');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
