# Security policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub security advisories:

1. Open the affected repository on GitHub.
2. Go to **Security** > **Advisories** > **Report a vulnerability**.
3. Describe the issue, the affected repo and commit or tag, the board
   (Vortex V1, Flux V1, or other) if relevant, and steps to reproduce.

Do not open a public issue, pull request or discussion for a suspected
vulnerability. Security advisories are the only reporting channel; there is no
separate security email address.

If you are unsure which repository is affected, report it against the lowest
layer you can identify (for example the driver rather than the HAL that uses
it). We will move it if needed.

## Scope

In scope:

- Firmware: product applications (`hardfoc-*`), board HALs (`hf-hal-*`) and
  `hf-core`.
- Drivers and libraries: `hf-*-driver`, `hf-core-drivers`, `hf-core-utils`,
  `hf-utils-*`, `hf-internal-interface-wrap`, `hf-pincfg`.
- CI and build tooling: `hf-general-ci-tools`, `hf-espidf-ci-tools`,
  `hf-espidf-project-tools`, and the GitHub Actions workflows in every repo
  (for example secret exposure or untrusted input reaching a privileged job).
- Boot and OTA: secure boot, flash encryption, firmware image signing and
  verification, update and rollback paths, and secure-element (SE050)
  integration.

Out of scope: vulnerabilities in third-party code we vendor or submodule
(ESP-IDF, FreeRTOS, ROBOTIS DYNAMIXEL SDK, CANopenNode and similar). Report
those upstream. Tell us as well if HardFOC's use of that code makes it
exploitable.

## What to expect

- We acknowledge a report within 2 business days.
- We confirm or reject it and share an initial assessment and fix plan after
  investigating, and keep you updated in the advisory thread.
- Fixes land on `main` and ship in a tagged release. The advisory is published
  once a fixed release is available. We credit reporters who want to be
  credited.

## Supported versions

Only the latest release of each repository receives security fixes. Products
that pin older submodule commits should move to a fixed release.
