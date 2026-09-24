# Arty console build verification — 2026-09-21

The initial full-model WebApp passed synthesis but failed board placement DRC:
71,866 logic LUTs required versus 63,400 available. The synthesized WebApp IP
reported 76,974 packed LUTs, 126,665 FFs, 51 RAMB18s, and 12 DSP blocks.
Its mutable-weight neural classifier accounted for 27,399 LUTs and 43,789 FFs.

Evidence is preserved at `/tmp/arty-full-model-evidence` (IP and optimized-board
checkpoints, original IP HDL, synthesis/implementation logs) and
`/tmp/arty-webapp-hierarchy.rpt`. No bitstream was produced or flashed from that
build. The capacity DRC was not disabled.

An intermediate fixed-default FFN specialization passed 18 release tests and
Vivado packaging/GHDL elaboration, but its physical build was stopped when the
requested scope changed to a WebApp-only board. No fit or timing claim is made
for that intermediate design.

The current application removes the rule, linear, and FFN classifiers, their
UART classification lines, and their private frame copy. The board removes the
matrix IP, its ports and HUB75 constraints, and the matrix build dependency.
The packaged WebApp is now the only external IP repository. EthernetLite,
clock/reset support, UART and activity LEDs remain.

All 16 WebApp-only release tests pass (`/tmp/arty-web-only-test.log`).
Vivado IP identity, pins, AXI, clock/reset and native GHDL elaboration also pass
(`/tmp/arty-web-only-package.log`). The clean board build is running in
`/tmp/arty-web-only-board-build.log`.
Physical fit, routed timing, bitstream generation and flash verification remain
to be recorded after the new package and clean board build complete.

## Resume on 2026-09-22

The environment interruption stopped Vivado during synthesis and cleared the
previous `/tmp` logs/toolchain snapshot. The source and generated package survived.
The build was resumed with `make build`, reusing completed EthernetLite and
clock/reset runs and restarting WebApp synthesis. The current persistent console
log is `livt-arty-a7-100t/work/console-build.log`; individual run logs are in
`work/WebAppFpga.runs`. Earlier `/tmp` paths above describe historical evidence
and are no longer available in this environment.

## Physical fit

WebApp synthesis completed with zero errors and zero critical warnings:
40,620 LUTs and 67,510 registers (previous full-classifier IP: 76,974 LUTs and
126,665 registers). The complete placed board uses 37,026 LUTs (58.40%),
66,412 registers (52.38%), and 29.5 block RAM tiles (21.85%). Capacity DRC passes.

The first routed result passes hold timing, but one HTTP decimal-digit path
misses setup by approximately 0.53 ns. Its existing four-cycle constraint is
unchanged. The console flow now enables AggressiveExplore post-route physical
optimization before timing validation and bitstream generation. This follow-up
run is logged in `livt-arty-a7-100t/work/console-build-physopt.log`.

## Successful bitstream build

`make build` completed successfully on 2026-09-22 with Vivado 2026.1.
Post-route AggressiveExplore closed the HTTP path without changing its timing
requirement. Final setup slack: +0.065 ns; hold slack: +0.051 ns; pulse-width
slack: +3.000 ns. There are zero failing timing endpoints; bus-skew checks pass.
Final utilization: 37,028 LUTs (58.40%), 66,412 registers (52.38%), and 29.5
block RAM tiles (21.85%). Bitstream DRC: zero errors, two warnings.
Residual DRC/CDC warnings are tracked as release issue #505.

Bitstream: `livt-arty-a7-100t/work/WebAppFpga.runs/impl_1/WebAppFpgaTop.bit`.
SHA-256: `54b95fd033b608e0c4982aa85cd6e20c8650171819b7c7517805375c6a793b85`.
`make flash ARTY_TARGET='*/210319AD2B13A'` is programming and verifying the
SPI flash; the final result will be recorded below.

## Programming handoff

Direct JTAG programming completed successfully on 2026-09-22 at 13:57:49:
Vivado reported `End of startup status: HIGH` and `PASS: direct JTAG programming`.
Log: `livt-arty-a7-100t/work/console-jtag-recovery.log`.
The WebApp bitstream is loaded in volatile FPGA configuration. Persistent SPI
flash programming/verification did not complete successfully in this session;
the initial erase completed, so flash contents must be treated as unverified.
The user is taking over manual programming. No programming client or hardware
server from this task remains active. No Ethernet/HTTP functional hardware test
was performed.


## Current composed stack: build blocked by LUT capacity (2026-09-23)

The user explicitly requested packaging the current Livt.WebApp/Livt.Web/Livt.Net,
building the Arty bitstream and flashing the connected board. This hardware run
is separate from the earlier Livt-only modernization verification.

- Release packaging, Vivado IP interface checks and packaged GHDL elaboration passed.
- A fresh board project used the newly packaged IP. Previous `work` artifacts were
  preserved at `/tmp/arty-net021/previous-work`.
- Removed obsolete `GetHeaderChecksumWordSum` timing exceptions. The retained
  decimal-digit exception was checked against the current generated state machine.
- WebApp synthesis: zero errors and zero critical warnings; 74,726 LUTs,
  85,766 registers, 23 RAMB18s (11.5 block RAM tiles).
- Default board optimization: placement stopped with DRC UTLZ-1,
  **73,157 logic LUTs required versus 63,400 available**.
- An isolated `opt_design -directive ExploreArea` experiment on the optimized
  checkpoint reduced the total to 70,357 LUTs (70,344 logic LUTs), 84,000 registers
  and 31 RAMB18s (15.5 tiles). This still exceeds capacity and is not a routed build.
  The experiment did not change the default board build strategy.
- Read-only hardware discovery found Digilent target `210319AD2B13A`, device
  `xc7a100t_0`. **No programming or flash erase was performed. No new bitstream
  was produced, and no new timing or on-board HTTP acceptance is claimed.**

The user requested investigation of duplicate storage and RAM opportunities while
preserving features. The synthesized endpoint RX array has three separate 1,024-bit
register banks: canonical data, write-local staging and write commit. Its 128 bytes
therefore occupy 3,072 storage registers, plus control. The endpoint RX buffer,
HTTP RX buffer and ICMP echo snapshot together use 6,071 LUTs and 10,775 registers
with no RAM. Twelve receive header-cache components add 15,621 LUTs and 18,574
registers, including control and views; these are not pure storage costs.

Logs/checkpoints and source SHA-256 manifest: `/tmp/arty-net021/` (`package.log`,
`build.log`, `hierarchy.rpt`, `area-hierarchy.rpt`, `storage-registers.txt`,
`source-hashes.json`). All recorded source files were unchanged at the end of
this analysis. RAM replacement savings and shared-parser savings require measured
follow-up; they cannot be inferred by subtracting full component totals.

## Shared packet storage and parsers (2026-09-23)

The endpoint now owns one 128-byte RX RAM and one Ethernet/IPv4 parser pair.
HTTP and network services borrow those parsers; ICMP uses an independent RAM
snapshot so its prepared response survives RX release and reuse. Small header
caches remain register arrays after an equal-operation RAM experiment increased
their resource cost.

- Livt suites: Net 103, Web 39, WebApp 19 passed; zero failures or skipped tests.
- New checks cover array/RAM byte parity, shared-parser read counts, failed reads,
  response stability after RX reuse, and repeated handling.
- Release packaging, Vivado IP interface validation, and packaged GHDL elaboration
  passed. The promoted source files match the verified snapshot.
- Isolated 128-byte storage probes: array 1,370 LUTs / 2,156 registers / no BRAM;
  RAM 1,042 LUTs / 1,068 registers / one RAMB18. Whole-board savings are measured
  separately; these probe totals do not establish fit.

The first full-board build fits: 54,038 LUTs (85.23%), 58,594 registers and 16.5
block RAM tiles after routing/physical optimization. WebApp IP synthesis uses
54,706 LUTs, 59,387 registers and 25 RAMB18s. Setup timing fails at -30.062 ns;
hold slack is +0.050 ns. No bitstream was generated or flashed from this run.

The worst paths combine TCP pseudo-header/header checksum arithmetic and signed
checksum folding. The corrected candidate uses scheduled TCP byte accumulation
and unsigned folding within the existing non-negative sum contract. All corrected
suites pass: Net 104, Web 39, WebApp 19, zero failures/skips; IP validation and
packaged HDL elaboration also pass. The corrected board build completed; see
the hardware acceptance result below.

The installed VHDL generator changed before this corrected verification round;
its identity is recorded in `timing-tool-hashes.json` and candidate sources in
`timing-sources.json`. Before/after whole-board measurements across compiler
identities do not isolate the contribution of individual source changes.

The previous image at 10.0.0.2 returns HTTP 200 (1,377 root-page bytes) and replies
to three ICMP probes with zero loss. This confirms the VM route before flashing;
no on-board acceptance of the new image is claimed yet.
Evidence: `/tmp/net022/`, including suite XML files,
`package.log`, `board-build.log`, `verified-sources.json` and `tool-hashes.json`.
The preceding failed build and package are preserved as `previous-work` and
`previous-package` in that directory.

## Corrected build and startup investigation (2026-09-24)

The corrected image uses **52,074 LUTs (82.14%)**, 57,745 registers and 16.5
block RAM tiles. Routed setup slack is **+0.542 ns**, hold slack **+0.047 ns**;
there are no failing timing endpoints. SPI programming and verification passed,
and configuration DONE is high. Rebooting and loading the same bitstream directly
through JTAG did not restore operation: ARP/HTTP do not respond and UART captures
are empty. The user observes LD6 (heartbeat) and LD4 (incoming MII RX) blinking.
Hardware acceptance therefore remains incomplete.

Bitstream SHA-256:
`5670b96901725c7edab25bf7023b3c511ed51eaf4d634891d440cf18acda0056`.
Build/programming evidence: `/tmp/net022/board-timing-build.log`, `flash.log`,
`jtag-console.log`, and the board's `work/timing_summary.rpt`.

A packaged RTL startup simulation with a responsive AXI slave passes (three MAC
initialization writes, continuing RX polling and UART activity). The exact
synthesized WebApp IP fails the same startup assertions under GHDL with Xilinx
primitive models: at 50 us, two AXI reads, zero writes and zero UART falling edges.
The caller leaves its wait state at 12,385 ns using the old idle/default result;
the borrowed read's registered busy signal rises only just after that edge.
The actual first AXI read begins at 12,515 ns. This is a concrete generated-call
handshake failure, reduced to compiler issue #538 before another production build.

Evidence: `/tmp/net022/boot-sim.log`, `ghdl-synth-boot.log`,
`synth-startup.vcd`, and `synth-boot/boot_tb.vhd`. Full-netlist XSIM and ILA debug
were unavailable under the installed BASIC license; no diagnostic image was
flashed. The GHDL result establishes a failure independent of the VM network.

The minimal generic Reader/Borrower confirms the same problem: ordinary RTL
returns 42 at 245 ns, whereas the unchanged synthesized RTL returns 0 at 205.1 ns.
A diagnostic using one clock event for all sequential processes reproduces at
205 ns, including with all optimizations disabled. The current generator also
reproduces; its SHA-256 is
`2b92459a8c103b6a9ef9abf2607a09ef3de65cd3634b6e5ba0afca3fe73d8457`.
Evidence and standalone synthesis scripts: `/tmp/net022/borrowed-handshake/`.
The normal RTL result alone is therefore insufficient for hardware acceptance.

## Resume after borrowed-call fix (2026-09-24)

Compiler #538's ordinary/common-clock first-completion and reset-interruption
reproduction passes with the installed generator:
`42fdb676453b12b8e739d267d806739faf8863a7f5c53a90aff987dfb6b19116`.
All 122 source hashes remained unchanged during verification. Fresh isolated
Livt suites pass: **Net 104, Web 39, WebApp 19**, zero failures or skips.
Release packaging, Vivado IP identity/interface checks and packaged HDL
elaboration pass.

The full-app common-clock startup check still fails: at 100 us it records
86 reads, three MAC writes and zero UART falling edges. SendLog accepts the
old GetTransmitSpace result 0 at 12,395 ns before busy and the current value
128 arrive. The initialization transaction order also remains inconsistent.

A reduced **owned** Reader with an unrelated public output field causes a
registered method-response accessor. Its first call returns 42 in ordinary RTL
at 305 ns, but 0 in common-clock RTL at 265 ns and the synthesized circuit at
265.1 ns. Removing the public field passes both RTL variants. This is recorded
separately as compiler #539; the verified #538 fix remains intact.

The fresh board build was stopped during synthesis after this failure was
confirmed. **No new bitstream was produced or flashed in this resume.** The
previous board artifacts are preserved at
`/tmp/net022-resume/previous-board-work`; the board retains its preceding image,
which has not passed network acceptance. No new fit/timing claim is made.

Evidence: `/tmp/net022-resume/` contains `sources.json`, `generator.sha256`,
`repro.log`, `{net,web,app}-tests.log`, `package.log`, `boot.log`,
`boot-trace3.log`, `owned-public-probe.log`, `owned-helper-probe.log`,
`owned-synthesis.log`, the synthesized checkpoint/netlist under
`owned-synthesis/synthesized/`, and `board-build.log`.

## Accepted build after owned-call fix (2026-09-24)

Compiler #539's ordinary/common-clock regression now passes for first and changing
results, output arguments and reset. Generator SHA-256:
`6b6d6bbdb99307134c42cced99450c148116456d606b8e97fd449a9fff69ba7c`.
Fresh isolated Livt suites pass: **Net 104, Web 39, WebApp 19** (162 total,
zero failures or skips). Packaging, Vivado IP validation and HDL elaboration pass.
The 122 recorded source hashes and packaged IP hashes were unchanged before flash.

The maintained `check-startup.py` / `startup_tb.vhd` check passes against the
packaged wrapper. At 100 us it observes the three expected MAC initialization
writes, 69 reads and five UART falling edges; RX polling starts after MAC setup.
Its temporary HDL uses one clock event for sequential processes, preserving
reset, context/data wiring and state machines. Production HDL is unchanged.

A fresh `make build` completes with **55,085 LUTs (86.88%), 58,015 registers and
16.5 BRAM tiles**. Routed setup slack is **+0.733 ns**, hold slack **+0.050 ns**,
and there are no failing timing endpoints. Existing timing constraints remain.

SPI erase, program and verification pass using `make -o build flash` after the
completed build. Configuration DONE is high. Following boot, the serial port
emits the complete banner `Eccelerators GmbH\r\nFPGA Conference 2026\r\n`.
The VM resolves 10.0.0.2 to the configured MAC `00:00:5e:00:fa:ce`; ping receives
three of three replies. HTTP checks return 200 and exactly the declared body
length for `/` (1377 bytes), `/about` (1321 bytes) and `/status` (1388 bytes).
Root content matches its source; status content matches with dynamic counters
normalized. This supersedes the failed startup results above.

The About response exactly matches its provider's published prefix, but that
provider has a **pre-existing content truncation**: its literal contains 1456
bytes while its declared length is 1321. The missing 135 bytes include closing
HTML. Existing tests assert the truncated extent. This is a separate application
content finding, not a successful full-document check or a transport failure.
No content source change or additional hardware build was made for it.

Bitstream SHA-256:
`35a97c6dc06a4f62c59afe4cab30123400d3778443002b11f59748ca061662b1`.
MCS SHA-256:
`def611fd3d4f3307ca861835e72cf3b5faa93cfbd1b1e0c6e46bb9be863d87a6`.

Evidence: `/tmp/net022-after539/` contains `generator.sha256`, `sources.json`,
`package-sha256.json`, `repro.log`, `{net,web,app}-tests.log`, `package.log`,
`startup.log`, `board-build.log`, `flash.log`, `uart-boot.{log,bin}`,
`board-acceptance.log`, `board-http-results.json`, `board-ping.log` and captured
HTTP headers/bodies. Final board reports are under its `work/` directory.
