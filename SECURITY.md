# Security Policy

## Security Model Summary

Hestia is designed to reduce plaintext exposure on the server side.

Current intended model:

- message content should be encrypted on the client before transmission
- file payloads should not be stored as readable plaintext message history on the server
- local conversation history stays on the client
- contact trust can be reinforced with key fingerprint verification

## Important Notes

Hestia is not a zero-metadata system.

The backend may still process or observe operational data needed for service delivery, including:

- account identifiers
- session activity
- delivery state
- connection timing
- IP addresses
- call signaling events
- attachment and queue handling metadata

Do not describe the system as anonymous or metadata-free.

## Fingerprint Verification

For sensitive conversations, users should compare and verify contact key fingerprints.

This helps detect unexpected key changes and strengthens trust beyond the default first-contact flow.

## No Plaintext Goal

The project goal is:

- no readable plaintext message history stored on the server as part of normal operation

Any deviation from that goal should be treated as a security issue and reviewed carefully before release.

## Responsible Disclosure

If you discover a security issue:

1. Do not publish exploit details immediately.
2. Contact the project maintainer privately first.
3. Include:
   - affected component
   - reproduction steps
   - impact
   - suggested mitigation if available
4. Allow reasonable time for triage and remediation before public disclosure.

If a dedicated security contact is added later, this file should be updated with the correct address.

## Scope

This policy applies to:

- Flutter client
- Node.js backend
- release and deployment configuration

It does not mean every current implementation detail has already been independently audited.
