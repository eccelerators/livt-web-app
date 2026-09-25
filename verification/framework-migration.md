# HTTP framework migration verification

The consumer now declares application paths and handlers through WebRoutes,
uses the default HttpServer assembly, and retains acquired RX through terminal TX
completion. The external WebApp pins are unchanged. This is Livt simulation
verification for the initial migration. Subsequent build, flash and successful
on-device checks are recorded in [board validation](framework-board-validation.md).

Development dependencies: sibling Livt.Web 1.0.0-dev and Livt.Net 1.1.0-dev;
registry Livt.IO 1.2.0-dev and Livt.Base 1.1.0. No package was published.

## Tests

Verification uses isolated snapshots with the same production sources and named
manifest test roots. This keeps clock-context validation of the complete board
separate from the HTTP-only tests. Run `livt test --events -v` in each snapshot.
The ordinary project manifest registers every consumer test for `livt test`,
including the slow full-page case. Use named filters for focused iteration.
The accepted verification basis is 184 distinct passing focused checks; full-page
simulation remains outstanding; subsequent board validation passed.

| Scope | Result |
|---|---|
| HTML stores and WebRoutesTest | 9 passed |
| Net FrameLinkTest and its fixture graph | 8 passed |
| WebApplicationTest: ARP/TX retention and failure recovery | 2 passed |
| WebApplicationTest: complete Home frame after handshake | Deferred; no completed passing run |
| WebAppTest: board-facing AXI startup | 1 passed |
| Livt.Web HTTP core (network adapter suite excluded) | 164 passed |

The expected Home frame is an independent byte fixture with Ethernet/IP/TCP
headers, checksums and the complete 1373-byte HTML body. Route tests independently
check exact HTTP headers, fallback messages, response extents and status digits.
Store tests check invalid reads and complete About closing markup. Home/status
HTTP responses are 1458 bytes; About is 1407 bytes, all within the 1460-byte budget.

The initial 179-test Web batch hit GHDL's 900000 ms timeout in the unchanged
HttpNetworkEndpointTest component after 21 tests had passed. That run is not
counted as a passing network regression suite. The 164 HTTP-core tests are run
separately; consumer integration covers the changed default assembly and RX/TX
ownership path. Long consumer cases run separately with live simulator output
and `LIVT_GHDL_TIMEOUT_MS=7200000` to avoid cutting off valid simulations.

The TX-failure recovery case also passed as a direct run of the unchanged
Livt-generated testbench compiled by GHDL GCC with `-m -f -O2 --std=08`.
This optimizes the host simulator; it does not synthesize or edit generated HDL.
The optimized simulator independently passed the ARP case as well (counted once).

## Toolchain reproducibility

An installed compiler extension changed during the initial run and caused an
invalid ZIP/class-loading error. Final runs use a ZIP-verified immutable copy of
the CLI/extensions in a temporary Java user home, without replacing the installed
toolchain. CLI SHA-256:
`99e046d7212e3259d33c428c02a4f56bd547fb723ba8e527929217f29beead39`.
VHDL extension SHA-256:
`6153374a4a7791317563a9ffb3b8b85587886553a9d08c873f83998798926361`.

Constructor-created graph nodes use explicit typed owned fields to avoid missing
package imports for constructor-local component signals. The minimal local form
fails elaboration; the field form passes. No generated HDL was edited.

The subsequent board validation uses the migrated graph and larger RX capture.

## Full-page test wait budget

The first full Home-frame case exhausted 200000 TX-ready polls at about 25 ms
of simulated time. A focused state trace confirmed successful parsing and HTTP
publication, with checksum preparation progressing through body bytes at roughly
12.4 microseconds per byte before the checked TX copy. The short-frame wait bound
was insufficient for the complete page. The test now permits 1000000 polls and
includes stage reports; expected frame bytes and assertions are unchanged.
Corrected reruns used Livt `-O all`, including a directly run generated bench
compiled with GHDL GCC `-O2`. They were stopped before a final result; no full-page
success is claimed. The failed short-budget run is not counted as passing
verification. The unchanged expected frame and corrected test are retained.

To resume the slow case, allow an appropriately long simulator timeout and run:

```sh
LIVT_GHDL_TIMEOUT_MS=7200000 livt test -O all --events -v -r WebApplicationTest:ServesCompleteHomeFrameAfterHandshake
```

The timeout is a wall-clock allowance, not evidence that the test will pass or
finish within it. Default-timeout aggregate runs are unsuitable for fast iteration.
