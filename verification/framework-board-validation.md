# HTTP framework board validation

Deployment requested on 2026-09-25 for the Arty A7-100T (`xc7a100tcsg324-1`).
This is separate from the 184 focused checks recorded in
[framework migration verification](framework-migration.md).

## Completed deployment

The updated image was built, flashed, verified and booted on 2026-09-25.
The FPGA DONE pin is high. UART emitted the complete startup banner and route
logs, and all eight complete HTTP response checks passed at `10.0.0.2`.

The first synthesis exposed merged same-named block-local UART arrays. Distinct
`homeMessage`, `aboutMessage`, and `statusMessage` locals preserve their 7/12/13
byte widths. Livt.Web now uses bounded subtractive Content-Length formatting,
unsigned TCP sequence arithmetic and width-bounded header descriptors. All 169
HTTP-core tests pass, including arithmetic and descriptor-boundary regressions.
Package interface/catalog checks, GHDL elaboration and packaged startup pass:
69 AXI reads, 3 writes and 5 UART falling edges within 100 microseconds, with
MAC programming before receive polling. Startup observation uses a temporary
single-physical-clock simulation normalization; production HDL is unmodified.

The board build applies ExploreArea followed by ExploreSequentialArea. The old
legacy encoder multicycle exception was removed; normal timing gates apply.

| Complete board design | Before source optimizations | Final |
|---|---:|---:|
| LUTs | 40,114 | 36,643 (57.80%) |
| Registers | 61,026 | 56,247 (44.36%) |
| Slices | 15,610 | 15,209 (95.96%) |
| BRAM tiles | 16 | 16 (11.85%) |
| Routed setup slack, 100 MHz | -9.500 ns | +1.252 ns |
| Routed hold slack | +0.050 ns | +0.011 ns |

Both columns use the same area optimization settings. All final user-specified
timing constraints are met. Slice packing remains close to capacity.

Build and flash in `livt-arty-a7-100t`:

```sh
env -u _JAVA_OPTIONS make build VIVADO=/tools/Xilinx/2026.1/Vivado/bin/vivado JOBS=4
env -u _JAVA_OPTIONS make flash VIVADO=/tools/Xilinx/2026.1/Vivado/bin/vivado JOBS=4 ARTY_TARGET=localhost:3121/xilinx_tcf/Digilent/210319AD2B13A
```

Program/Verify completed successfully and the board booted from flash.
Bitstream SHA-256:
`25a4d1c8a86a860831f1651b38cb49d84c2507e1ea5e44023c7ceb1bcb76c800`.

## On-device checks

The completed board check can be repeated with:

```sh
python3 verification/check-board-http.py --host 10.0.0.2 --output /tmp/board-http
```

This opt-in checker compares complete response headers and bodies for Home,
About, status, a query-string route, missing/trailing-slash routes, unsupported
POST, and another Home request. Only the six mutable status counter digits are
masked, after validating them as hexadecimal. It saves each HTTP response and
its result. It does not flash the board.

Observed results: Home/status bodies were 1373 bytes, About/query bodies 1322,
404 bodies 10 and the 405 body 19. Repeating Home after the error routes also
passed. Exact headers, complete bodies and connection closure were checked.
Transient run artifacts are under `/tmp/web009-board`: `build-web010.log`,
`flash-web010.log`, `http-web010/results.json`, saved HTTP responses and
`uart-web010.bin`. Reports are also in the board project's `work` directory.

Socket-level checks do not replace the deferred raw-frame simulation's checksum,
TX backpressure and RX-release assertions. Packet capture is unavailable in this
VM without additional OS privileges; no raw-packet capture is claimed.
The existing receive-error acknowledgement/recovery gap also remains open.

## Reproducibility

The deployment uses an immutable, ZIP-verified compiler snapshot rather than
changing an installed toolchain during generation. CLI SHA-256:
`59f9d15d5d4855e311a44890978df0ebbdd0af8a5c12a94571d0c3a3384cfafb`.
VHDL extension SHA-256:
`468b73b6422137d75a61d91b6ea6968292e5aa9eaf30da0586255496234c5cfe`.
Vivado 2026.1; GHDL GCC backend. No generated production HDL was edited.
