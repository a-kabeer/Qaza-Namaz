import fs from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  doc,
  getDoc,
  setDoc,
} from 'firebase/firestore';

const rules = fs.readFileSync('firestore.rules', 'utf8');
const testEnv = await initializeTestEnvironment({
  projectId: 'qaza-nmz',
  firestore: { rules },
});

const userA = testEnv.authenticatedContext('user-a');
const userB = testEnv.authenticatedContext('user-b');
const dbA = userA.firestore();
const dbB = userB.firestore();

const stateA = doc(dbA, 'users/user-a/syncMetadata/state');
const validState = {
  generation: 0,
  resetInProgress: false,
};

await assertSucceeds(setDoc(stateA, validState));

const recordA = doc(dbA, 'users/user-a/qazaRecords/record-a');
const validRecord = {
  id: 'record-a',
  userId: 'user-a',
  prayerType: 'fajr',
  originalDate: '2020-01-15',
  status: 'pending',
  completedAt: null,
  createdAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
  updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
  syncGeneration: 0,
};

await assertSucceeds(setDoc(recordA, validRecord));
await assertSucceeds(getDoc(recordA));
await assertFails(
  getDoc(doc(dbB, 'users/user-a/qazaRecords/record-a')),
);
await assertFails(
  setDoc(
    doc(dbB, 'users/user-a/qazaRecords/record-b'),
    validRecord,
  ),
);

await assertFails(
  setDoc(
    doc(dbA, 'users/user-a/qazaRecords/record-invalid-field'),
    {...validRecord, id: 'record-invalid-field', unexpected: true},
  ),
);

await assertFails(
  setDoc(
    doc(dbA, 'users/user-a/qazaRecords/record-invalid-prayer'),
    {...validRecord, id: 'record-invalid-prayer', prayerType: 'invalid'},
  ),
);

await assertFails(
  setDoc(
    doc(dbA, 'users/user-a/qazaRecords/record-invalid-completion'),
    {
      ...validRecord,
      id: 'record-invalid-completion',
      status: 'pending',
      completedAt: Timestamp.fromDate(
        new Date('2026-01-02T00:00:00Z'),
      ),
    },
  ),
);

await assertFails(
  setDoc(
    doc(dbA, 'users/user-a/qazaRecords/record-invalid-generation'),
    {...validRecord, id: 'record-invalid-generation', syncGeneration: 99},
  ),
);

await assertSucceeds(
  setDoc(
    recordA,
    {
      ...validRecord,
      status: 'completed',
      completedAt: Timestamp.fromDate(
        new Date('2026-01-02T00:00:00Z'),
      ),
      updatedAt: Timestamp.fromDate(
        new Date('2026-01-02T00:00:00Z'),
      ),
    },
  ),
);

await assertFails(
  setDoc(
    recordA,
    {
      ...validRecord,
      status: 'completed',
      completedAt: Timestamp.fromDate(
        new Date('2026-01-03T00:00:00Z'),
      ),
      updatedAt: Timestamp.fromDate(
        new Date('2026-01-03T00:00:00Z'),
      ),
    },
  ),
);

const validChange = {
  changeType: 'complete',
  generation: 0,
  createdAt: Timestamp.fromDate(
    new Date('2026-01-02T00:00:00Z'),
  ),
  records: [validRecord],
};

await assertSucceeds(
  setDoc(
    doc(dbA, 'users/user-a/qazaChanges/change_batch_abcdef1234567890'),
    validChange,
  ),
);

await assertFails(
  setDoc(
    doc(dbA, 'users/user-a/qazaChanges/invalid-change'),
    {...validChange, unexpected: true},
  ),
);

await assertFails(
  setDoc(
    doc(dbA, 'users/user-a/syncMetadata/state'),
    {...validState, unexpected: true},
  ),
);

await assertFails(
  setDoc(
    stateA,
    {
      ...validState,
      generation: 99,
      resetInProgress: false,
    },
  ),
);

await assertSucceeds(
  setDoc(
    stateA,
    {
      generation: 1,
      resetInProgress: true,
      resetOperationId: 'reset_test_001',
      lastCompletedResetOperationId: null,
    },
  ),
);

await assertSucceeds(
  setDoc(
    stateA,
    {
      generation: 1,
      resetInProgress: false,
      resetOperationId: null,
      lastCompletedResetOperationId: 'reset_test_001',
    },
  ),
);

await testEnv.cleanup();
console.log('Firestore security rule negative/positive smoke tests passed.');
