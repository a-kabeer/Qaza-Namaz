#!/usr/bin/env node

import { initializeApp, deleteApp } from 'firebase/app';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
} from 'firebase/auth';
import {
  connectFirestoreEmulator,
  deleteDoc,
  doc,
  getDoc,
  getFirestore,
  setDoc,
  writeBatch,
  Timestamp,
} from 'firebase/firestore';

const PROJECT = 'qaza-nmz';
const AUTH_HOST = '127.0.0.1';
const AUTH_PORT = 9099;
const FIRESTORE_HOST = '127.0.0.1';
const FIRESTORE_PORT = 8080;

const appConfig = {
  apiKey: 'fake-api-key',
  authDomain: PROJECT + '.firebaseapp.com',
  projectId: PROJECT,
  appId: '1:895430705174:web:security-regression',
};

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

async function createEmulatorUser(label) {
  const app = initializeApp(appConfig, 'security-' + label + '-' + Date.now());
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://' + AUTH_HOST + ':' + AUTH_PORT, {
    disableWarnings: true,
  });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, FIRESTORE_HOST, FIRESTORE_PORT);

  const credential = await createUserWithEmailAndPassword(
    auth,
    label + '@example.com',
    'Passw0rd!123456',
  );

  return {
    app,
    db,
    uid: credential.user.uid,
  };
}

async function main() {
  const userA = await createEmulatorUser('a');
  const userB = await createEmulatorUser('b');
  const emptyStateUser = await createEmulatorUser('empty-state');

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
  await setDoc(emptyRecord, childFields(1));
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
  const anonymousApp = initializeApp(
    appConfig,
    'security-anonymous-' + Date.now(),
  );
  const anonymousDb = getFirestore(anonymousApp);
  connectFirestoreEmulator(
    anonymousDb,
    FIRESTORE_HOST,
    FIRESTORE_PORT,
  );
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

  await Promise.all([
    deleteApp(userA.app),
    deleteApp(userB.app),
    deleteApp(emptyStateUser.app),
    deleteApp(anonymousApp),
  ]);

  console.log('Firebase Auth + Firestore Emulator security tests passed.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
