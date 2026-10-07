#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  getFirestore,
  setDoc,
  writeBatch,
  Timestamp,
} from 'firebase/firestore';

const PROJECT = 'qaza-nmz';
const FIRESTORE_HOST = '127.0.0.1';
const FIRESTORE_PORT = 8080;


async function expectDenied(label, operation) {
  try {
    await operation();
    throw new Error(label + ': expected permission denied');
  } catch (error) {
    const code = error?.code ?? '';
    if (!String(code).includes('permission-denied')) {
      throw error;
    }
  }
}

function rootFields(state = 'ready', generation = 1) {
  return {
    schemaVersion: 1,
    cloudGeneration: generation,
    datasetState: state,
    updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
    bootstrapComplete: state === 'ready' || state === 'deleted',
  };
}

function childFields(generation = 1) {
  return {
    schemaVersion: 1,
    cloudGeneration: generation,
    entityVersion: 1,
    updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
    writerDeviceId: 'device-test',
    operationId: 'op-test',
    payload: {
      id: 'record-1',
      recordVersion: 1,
    },
  };
}

async function createTestUser(testEnv, uid) {
  const context = testEnv.authenticatedContext(uid);
  const db = context.firestore();
  return { context, db, uid };
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

  const userA = await createTestUser(testEnv, 'security-user-a');
  const userB = await createTestUser(testEnv, 'security-user-b');
  const emptyStateUser = await createTestUser(testEnv, 'security-empty-state');

  const root = doc(userA.db, 'users', userA.uid);
  const emptyRoot = doc(
    emptyStateUser.db,
    'users',
    emptyStateUser.uid,
  );
  const emptyRecord = doc(
    emptyStateUser.db,
    'users',
    emptyStateUser.uid,
    'qazaRecords',
    'empty-state-record',
  );

  // An existing empty root is a valid historical state. It must transition
  // through initializing before child writes are allowed.
  await setDoc(emptyRoot, rootFields('empty', 1));
  await expectDenied(
    'Empty to ready without initialization',
    () => setDoc(emptyRoot, rootFields('ready', 1)),
  );
  await expectDenied(
    'Child write while root is empty',
    () => setDoc(emptyRecord, childFields(1)),
  );
  await setDoc(emptyRoot, rootFields('initializing', 1));
  await setDoc(emptyRecord, childFields(1, 'empty-state-record'));
  await setDoc(emptyRoot, rootFields('ready', 1));
  await expectDenied(
    'Ready to initializing in the same generation',
    () => setDoc(emptyRoot, rootFields('initializing', 1)),
  );

  const record = doc(userA.db, 'users', userA.uid, 'qazaRecords', 'record-1');
  const badGeneration = doc(
    userA.db,
    'users',
    userA.uid,
    'qazaRecords',
    'bad-generation',
  );
  const badSchema = doc(
    userA.db,
    'users',
    userA.uid,
    'qazaRecords',
    'bad-schema',
  );
  const deletingRecord = doc(
    userA.db,
    'users',
    userA.uid,
    'qazaRecords',
    'deleting-state',
  );

  // Owner can create and read their root and child data.
  await setDoc(root, rootFields('initializing', 1));
  await setDoc(root, rootFields('ready', 1));
  await setDoc(record, childFields(1));

  // Exercise a realistic backup batch. The production worker now chunks
  // versioned writes at 100 operations, well below Firestore's 500-write
  // limit, while keeping the rules evaluation bounded and repeatable.
  const ownerBatch = writeBatch(userA.db);
  for (let i = 0; i < 100; i += 1) {
    ownerBatch.set(
      doc(
        userA.db,
        'users',
        userA.uid,
        'qazaRecords',
        'batch-' + i,
      ),
      {
        ...childFields(1),
        payload: {
          id: 'batch-' + i,
          recordVersion: 1,
        },
      },
    );
  }
  await ownerBatch.commit();

  const ownerRead = await getDoc(record);
  if (!ownerRead.exists()) {
    throw new Error('Owner could not read their own record.');
  }

  // Cross-user traversal is denied for both read and write.
  await expectDenied(
    'Cross-user read',
    () => getDoc(
      doc(
        userB.db,
        'users',
        userA.uid,
        'qazaRecords',
        'record-1',
      ),
    ),
  );
  await expectDenied(
    'Cross-user write',
    () => setDoc(
      doc(
        userB.db,
        'users',
        userA.uid,
        'qazaRecords',
        'record-1',
      ),
      childFields(1),
    ),
  );

  const crossUserBatch = writeBatch(userB.db);
  for (let i = 0; i < 25; i += 1) {
    crossUserBatch.set(
      doc(
        userB.db,
        'users',
        userA.uid,
        'qazaRecords',
        'cross-batch-' + i,
      ),
      {
        ...childFields(1),
        payload: {
          id: 'cross-batch-' + i,
          recordVersion: 1,
        },
      },
    );
  }
  await expectDenied('Cross-user batched write', () => crossUserBatch.commit());

  // Unauthenticated access is denied.
  const anonymousDb = testEnv.unauthenticatedContext().firestore();
  await expectDenied(
    'Unauthenticated read',
    () => getDoc(doc(
      anonymousDb,
      'users',
      userA.uid,
      'qazaRecords',
      'record-1',
    )),
  );

  // Invalid generation and missing metadata are denied.
  await expectDenied(
    'Invalid generation',
    () => setDoc(badGeneration, childFields(2)),
  );
  await expectDenied(
    'Missing metadata',
    () => setDoc(
      badSchema,
      {
        schemaVersion: 1,
        cloudGeneration: 1,
      },
    ),
  );

  // Illegal lifecycle transitions are denied.
  await expectDenied(
    'Deleting from ready in the same generation',
    () => setDoc(root, rootFields('deleted', 1)),
  );
  await expectDenied(
    'Skipping generation',
    () => setDoc(root, rootFields('initializing', 3)),
  );

  // A new generation can enter deleting, and child writes are denied.
  await setDoc(root, rootFields('deleting', 2));
  await expectDenied(
    'Child write while deleting',
    () => setDoc(deletingRecord, childFields(2)),
  );
  await setDoc(root, rootFields('deleted', 2));

  // Root deletion is always denied.
  await expectDenied('Root deletion', () => deleteDoc(root));

  await testEnv.cleanup();

  console.log('Firestore Security Rules emulator tests passed.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
