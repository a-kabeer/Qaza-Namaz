#!/usr/bin/env python3
"""Minimal real Auth + Firestore Emulator security regression suite."""

import json
import time
import urllib.error
import urllib.request

PROJECT = "qaza-nmz"
AUTH_URL = "http://127.0.0.1:9099"
FIRESTORE_URL = (
    "http://127.0.0.1:8080/v1/projects/"
    + PROJECT
    + "/databases/(default)/documents"
)


def request_json(url, method="GET", body=None, token=None, expected=None):
    data = None
    headers = {"Content-Type": "application/json"}
    if body is not None:
        data = json.dumps(body).encode()
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            status = response.status
            payload = response.read().decode()
    except urllib.error.HTTPError as exc:
        status = exc.code
        payload = exc.read().decode()
    if expected is not None and status not in expected:
        raise AssertionError(
            f"Unexpected HTTP {status} for {method} {url}: {payload}"
        )
    return status, json.loads(payload) if payload else {}


def wait_for(url):
    deadline = time.time() + 60
    while time.time() < deadline:
        try:
            request_json(url, expected={200, 404})
            return
        except Exception:
            time.sleep(1)
    raise RuntimeError("Firebase emulator did not become ready: " + url)


def signup(email):
    _, payload = request_json(
        AUTH_URL
        + "/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key",
        method="POST",
        body={"email": email, "password": "Passw0rd!123456", "returnSecureToken": True},
        expected={200},
    )
    return payload["localId"], payload["idToken"]


def doc_url(path):
    return FIRESTORE_URL + "/" + path


def integer(value):
    return {"integerValue": str(value)}


def string(value):
    return {"stringValue": value}


def timestamp(value):
    return {"timestampValue": value}


def boolean(value):
    return {"booleanValue": value}


def root_fields(state="ready", generation=1):
    return {
        "schemaVersion": integer(1),
        "cloudGeneration": integer(generation),
        "datasetState": string(state),
        "updatedAt": timestamp("2026-01-01T00:00:00Z"),
        "bootstrapComplete": boolean(state == "ready"),
    }


def child_fields(generation=1):
    return {
        "schemaVersion": integer(1),
        "cloudGeneration": integer(generation),
        "entityVersion": integer(1),
        "updatedAt": timestamp("2026-01-01T00:00:00Z"),
        "writerDeviceId": string("device-test"),
        "operationId": string("op-test"),
        "payload": {
            "mapValue": {
                "fields": {
                    "id": string("record-1"),
                    "recordVersion": integer(1),
                }
            }
        },
    }


wait_for(AUTH_URL)
wait_for("http://127.0.0.1:8080")

uid_a, token_a = signup("a@example.com")
uid_b, token_b = signup("b@example.com")

# Owner can create/read their root and child data.
root = doc_url("users/" + uid_a)
request_json(
    root,
    method="PATCH",
    token=token_a,
    body={"fields": root_fields()},
    expected={200},
)
record = doc_url("users/" + uid_a + "/qazaRecords/record-1")
request_json(
    record,
    method="PATCH",
    token=token_a,
    body={"fields": child_fields()},
    expected={200},
)
request_json(record, token=token_a, expected={200})

# Cross-user traversal is denied for both read and write.
request_json(record, token=token_b, expected={403})
request_json(
    record,
    method="PATCH",
    token=token_b,
    body={"fields": child_fields()},
    expected={403},
)

# Unauthenticated access is denied.
request_json(record, expected={403})

# Invalid generation and missing metadata are denied.
request_json(
    doc_url("users/" + uid_a + "/qazaRecords/bad-generation"),
    method="PATCH",
    token=token_a,
    body={"fields": child_fields(generation=2)},
    expected={403},
)
invalid = {
    "fields": {
        "schemaVersion": integer(1),
        "cloudGeneration": integer(1),
    }
}
request_json(
    doc_url("users/" + uid_a + "/qazaRecords/bad-schema"),
    method="PATCH",
    token=token_a,
    body=invalid,
    expected={403},
)

# Invalid lifecycle state disables child writes.
request_json(
    root,
    method="PATCH",
    token=token_a,
    body={"fields": root_fields(state="deleted", generation=1)},
    expected={200},
)
request_json(
    doc_url("users/" + uid_a + "/qazaRecords/deleted-state"),
    method="PATCH",
    token=token_a,
    body={"fields": child_fields()},
    expected={403},
)

# Root deletion is always denied.
request_json(root, method="DELETE", token=token_a, expected={403})

print("Firebase Auth/Firestore Emulator security tests passed.")
