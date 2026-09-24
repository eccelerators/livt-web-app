# Issue #497 migration evidence

Date: 2026-09-21. Development checkouts are used; no packages have been published.

## Toolchain

- `livt.jar` SHA-256: `3d3f8df67ee6df48149ae570ade127938b84280dd7fb2a37c5cd9c6b41a46ddc`
- `extensions/livt-gen-vhdl.jar` SHA-256: `9404d95e70205ed8c3887e652595a04ec02a54e0f293bcbdaf5533ef8876e388`
- GHDL: `/home/vagrant/ghdl/bin/ghdl`, 6.0.0, 100 MHz simulation context.
- CLI and extensions were copied to an isolated tool home to keep the run stable.

## Sources

| Package | Version | Git HEAD |
| --- | --- | --- |
| livt-net | 1.1.0-dev | `8f51640` plus working-tree changes |
| livt-io | 1.2.0-dev | `b18f5e9` plus working-tree changes |
| livt-web | 0.1.0 | `1722bfb` plus working-tree changes |
| livt-base | 1.1.0 | `6d65e82` plus working-tree changes |
| livt-web-app | 0.1.0 | `7bf1a31` plus working-tree changes |

## Changes

- WebApp uses `IBufferedUart` backed by `BufferedUart<64,128>`, with enqueue acceptance handling and best-effort whole-message logging.
- Classification output needs up to 65 bytes, including CRLF; the old 45-byte guard could allow truncation.
- Main waits for TX ownership to return before consuming another RX frame. It uses the checked Net begin/write/submit APIs.
- Web fixtures keep a complete packet array and copy all 128 bytes before each RX submission. ARP and HTTP tests use separate TX instances when their slaves never complete.
- The old transitive Base package uses `match` as a variable; Base 1.1.0 fixes that keyword conflict. The configured registry did not resolve Base 1.1.0, so the development manifest uses the sibling checkout.
- IO, Net, Web and Base are explicit local dependencies; the app lock file records their resolved paths and checksums. Math 0.3.1, ML 0.2.0 and EthernetFrameClassifier 0.1.0 remain released dependencies.

## Verified Net gates

- 56/56 tests pass: `/tmp/livt497-net-test.log`.
- All 12 invalid capacities are rejected by both validate and build (24 checks): `/tmp/livt-net-invalid-tj7kntxw`.
- Native debug HDL passes synchronous and asynchronous reset runs, each completing at 1,604,176 ns: `/tmp/livt497-axi-sync.log` and `/tmp/livt497-axi-async.log`.
- These reruns use unmodified generated HDL. The earlier compiler-fix verification also covered all eight profile/optimization/reset combinations; see Net’s migration evidence.

## Consumer validation

- Isolated app debug suite: 16/16 pass, no skips (`/tmp/livt497-app.log`).
- App dependency synchronization succeeds with the final development manifest (`/tmp/livt497-sync.log`).

- Actual app checkout, release suite: 16/16 pass, no skips (`/tmp/livt497-app-release.log`).
- Livt.Web suite: 34/34 pass, no skips (`/tmp/livt497-web.log`). Its production source and migrated tests match the restored checkout byte for byte.
- The first full-app UART run at 100 MHz exceeded its 180-second wall-clock limit without reporting a functional assertion failure. This is recorded as a timeout, not a pass (`/tmp/livt497-uart.log`). The harness now retains partial simulator logs on timeout and supports a 10 MHz clock configuration for faster regression runs at the same 115200-baud setting.

- Native UART at 10 MHz / 115200 baud passes for debug and release HDL, each completing at 8,173,350 ns. Both complete banners, idle periods and reset/restart behavior are checked. Logs: `/tmp/livt497-uart-10mhz.log` and `/tmp/livt497-uart-release.log`; detailed harness evidence: `/tmp/livt-webapp-uart-3lpoe4fq` and `/tmp/livt-webapp-uart-05o6erp2`.
- Initial `numeric_std` metavalue warnings occur during reset settling; no functional assertion fails. Generated HDL is unmodified.

All development integration checks are complete. Publishing package versions,
physical FPGA timing/resource measurements and board deployment are separate
work; this verification does not claim those results.
