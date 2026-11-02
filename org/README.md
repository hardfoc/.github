# Org metadata

`org-metadata.json` is the source of truth for the description, homepage and
topics of every repository in the `hardfoc` org. `apply-metadata.sh` compares
it against GitHub and, when asked, writes the differences.

## Running it

Requires `gh` authenticated as an org admin, and `jq`.

```bash
# Show what would change (default, writes nothing)
./org/apply-metadata.sh

# Write the changes
./org/apply-metadata.sh --apply

# Limit to one or more repos
./org/apply-metadata.sh --repo hf-core --repo hf-core-utils
```

The script is idempotent: a repo that already matches prints `ok` and is not
touched. Entries with `"skip": true` are reported and left alone unless
`--include-skipped` is passed.

Description and homepage are set with `gh repo edit`; topics are replaced as a
set with `gh api -X PUT repos/<org>/<repo>/topics`, so topics added by hand in
the GitHub UI are removed on the next `--apply`. Add them to the JSON instead.

## CODEOWNERS

GitHub has no org-wide CODEOWNERS, so each repo carries `.github/CODEOWNERS`.
`add-codeowners.sh` opens one PR per repo on branch `chore/codeowners`
(dry run by default, `--apply` to open PRs). It skips repos that already have
the file or the branch, and the repos owned by other workstreams
(`hf-hal-*-v1`, `hardfoc-*-v1`, `hf-tmc5160-driver`).

```bash
./org/add-codeowners.sh            # list
./org/add-codeowners.sh --apply    # open PRs
```

## Editing the metadata

Edit `org-metadata.json`, run the dry run, open a PR. After it merges, run
`--apply`.

### Description templates

| Kind | Template |
|------|----------|
| driver | `Hardware-agnostic C++<std> driver for the <Vendor> <CHIP> <function> (<bus>). Part of the HardFOC ecosystem.` |
| core library | `HardFOC <component>: <what it provides>.` |
| HAL | `HardFOC hardware abstraction layer for the <Board> V<n> board (ESP32 / ESP-IDF), built on hf-core.` |
| product | `HardFOC <Board> V<n> <board type> application firmware (ESP32 / ESP-IDF).` |
| tooling | `HardFOC <tool name>: <purpose>.` |
| docs | `HardFOC <doc set>: <scope>.` |
| legacy | `[Legacy] <what it was>; superseded by <repo>.` |

Name every part the code actually supports (for example
`AT25010B/AT25020B/AT25040B`), and only state a C++ standard when the README
and the build files agree. Do not refer to boards by the old name
"HardFOC-V1"; the boards are Vortex V1 and Flux V1.

### Topic vocabulary

Topics are lowercase, hyphenated, at most 20 per repo. Pick from these groups:

| Group | Topics |
|-------|--------|
| always | `hardfoc` |
| code repos | `embedded`, `cpp` |
| role | `driver`, `library`, `hal`, `firmware`, `ci-tools`, `documentation`, `legacy` |
| portability | `hardware-agnostic` |
| platform | `esp32`, `esp-idf`, `freertos` |
| bus | `spi`, `i2c`, `uart`, `rs485`, `can`, `canopen`, `modbus`, `adc`, `rmt`, `pwm`, `gpio` |
| function | `adc`, `encoder`, `magnetic-encoder`, `eeprom`, `imu`, `sensor-fusion`, `pressure-sensor`, `flow-meter`, `mass-flow-controller`, `gas-sensor`, `oxygen-sensor`, `temperature-sensor`, `thermistor`, `ntc`, `motor-driver`, `motor-control`, `stepper-motor`, `bldc`, `foc`, `solenoid-driver`, `gpio-expander`, `pmic`, `battery-charger`, `secure-element`, `security`, `led`, `ws2812`, `neopixel`, `oled`, `display`, `servo`, `utilities`, `rtos` |
| vendor | `texas-instruments`, `ams`, `bosch`, `ceva`, `nxp`, `microchip`, `infineon`, `trinamic`, `analog-devices`, `alicat`, `pyroscience`, `sensirion`, `robotis`, `nkk` |
| chip | lowercase part number, e.g. `tmc9660` (one per supported part) |
| board | `vortex`, `flux` |

### Homepage

`https://hardfoc.github.io/<repo>/` only when the docs site is deployed and
returns HTTP 200; otherwise empty. Private repos have no homepage. When a
repo's docs go live, set its `homepage` in the JSON and re-run `--apply`.

### Versioning

SemVer tags `vX.Y.Z` (pre-release `vX.Y.Z-rc.N`) on `main`. Every tag gets a
GitHub Release named `vX.Y.Z` with generated notes; docs publish on tag push.

## Branch and tag protection

`apply-rulesets.sh` applies the rulesets in `rulesets/` to every public,
non-archived repo. The org is on GitHub Free, where org-level rulesets are not
available and rulesets only protect public repos, so each repo gets its own
copy. The script lists the private repos it cannot protect.

| Ruleset | Applies to | Rules | Bypass |
|---|---|---|---|
| `main-integrity` | default branch | no deletion, no force-push, linear history | none |
| `main-review` | default branch | pull request with 1 approving review, code-owner review, resolved conversations; squash merge only | org owners and repo admins, through a pull request |
| `release-tags` | `v*.*.*` tags | no deletion, no moving | org owners |

The review rule is a separate ruleset because GitHub applies a ruleset's
bypass list to every rule in it: owners can merge without a second reviewer,
while history protection still applies to everyone. Moving major tags such as
`v1` are not covered, so the CI tools release workflows can update them.

Required status checks are added per repo once that repo has a `CI gate`
job. The check to require is `CI gate / gate` when the gate comes from the
reusable `ru-ci-gate.yml` workflow.

```bash
./org/apply-rulesets.sh            # dry run
./org/apply-rulesets.sh --apply    # create or update
```


## Security features

`apply-security.sh` turns on GitHub's free security features for every public,
non-archived repo: secret scanning, push protection, Dependabot alerts,
Dependabot security updates, and private vulnerability reporting (the channel
`SECURITY.md` points reporters to). Private repos are skipped because these
features need GitHub Advanced Security on private repos.

```bash
./org/apply-security.sh            # dry run: current state per repo
./org/apply-security.sh --apply    # enable whatever is off
```

## Merge settings

`apply-merge-settings.sh` turns on *Automatically delete head branches* in every
non-archived repo, public and private, so a pull request's branch is deleted
when it merges. GitHub retargets open pull requests based on that branch to its
base first, so stacked pull requests keep working. A deleted branch can be
restored from its merged pull request.

```bash
./org/apply-merge-settings.sh            # dry run: current state per repo
./org/apply-merge-settings.sh --apply    # turn it on where it is off
```
