# Web-app migration verification

The application uses registry Net/Web/IO/Base dependencies selected in
`livt.toml`. Historical migration runs used sibling Net/Web sources. Run `livt sync` after changing dependencies. For current
focused checks and the deferred full-page simulation, see
[framework migration verification](framework-migration.md). The older aggregate
and UART commands below can take substantially longer:

```sh
livt test
livt test -R
python3 verification/run-uart.py --generated out/debug
python3 verification/run-uart.py --generated out/release
```

Set `LIVT_GHDL_PATH` or pass `--ghdl` when GHDL is not on PATH. Build the chosen
configuration before running its native check. The runner reads unmodified HDL,
generates a temporary harness, and retains logs in the printed directory.

The UART check decodes the actual top-level TX pin at 10 MHz / 115200 baud,
8N1. It sets the existing HDL clock generic without editing generated source.
Use `--clock-hz 100000000` for the slower 100 MHz simulation. It verifies every startup-banner byte and stop bit, checks that the banner
is not repeated while EthernetLite is stalled, resets the application, and
checks the complete banner again. A watchdog makes missing output fail.

Run the Livt.Web suite in its owning checkout to verify HTTP behavior and the
updated full-prefix RX injection fixtures. Net owns the native Ethernet transfer
and invalid-capacity checks in its `verification/ethernet` directory.

See [migration evidence](migration-evidence.md) for the toolchain and results.
These simulations do not establish physical FPGA timing closure or board results.

See [framework board validation](framework-board-validation.md) for the current
deployment attempt and the opt-in complete HTTP response checker.

## Packaged Arty startup

After `python3 scripts/package-ip.py`, run:

```sh
python3 verification/check-startup.py
```

This checks the actual 100 MHz board wrapper against a responsive AXI slave.
It verifies the two configured MAC words and programming command, requires
initialization before RX polling, and requires UART TX activity within 100 us.
It does not inject Ethernet traffic or decode the complete UART banner.

The simulation uses one clock observation for all sequential consumers in
**temporary** copies of the single-clock IP. This prevents clock-copy delta
ordering from hiding early method completion; production/package HDL is untouched.
Do not apply this transformation to designs containing clock-domain crossings.
Use `--work-dir /tmp/webapp-startup-check` with a new path to retain the harness.
A failure blocks the board build; a pass still requires routed timing and actual
ARP/ICMP/HTTP acceptance on the board.
