# Livt.WebApp

`Livt.WebApp` is a small FPGA web-application showcase built with the
[Livt](https://eccelerators.com/livt) hardware programming language. It wires reusable
networking and HTTP components into one top-level application that can receive
Ethernet frames, serve static HTML routes, report simple runtime counters over a
status page, and emit UART diagnostics.

The application is intentionally narrow: it demonstrates a fixed-function
connected FPGA design without an operating system or soft CPU. Reusable protocol
logic lives in `Livt.Net` and `Livt.Web`; this package owns the showcase content,
route meanings, UART logging, and Vivado IP top-level wiring.

## Package

```toml
[dependencies]
Livt.WebApp = "0.1.0"
```

`Livt.WebApp` depends on:

- `Livt.Web 0.1.0` for HTTP endpoint dispatch and response framing.
- `Livt.Net 1.1.0-dev` for Ethernet, ARP, IPv4, ICMP, TCP, checksum, frame I/O,
  and AXI EthernetLite boundary components.
- `Livt.IO 1.2.0-dev` for UART and memory primitives used directly by the
  application.

The development manifest uses sibling checkouts for IO, Net, Web, and Base.
Base 1.1.0 replaces the older transitive package whose `match` variable conflicts
with the current language keyword. Keep these checkouts beside this project;
publishing requires replacing
the development paths with verified package versions.
The packaging command refreshes local path checksum entries before building
because CLI issue #500 hashes generated output and Git metadata along with source.
Registry checksums and version pins remain intact; local source changes must be
tracked through the sibling checkouts. Ordinary CLI builds can still encounter
#500 after a sibling checkout changes.

## UART and frame ownership

The application uses `IBufferedUart` backed by `BufferedUart<64, 128>` at the
default 115200 baud, 8 data bits, no parity, and one stop bit. Main is the sole
transmit producer. Logging checks free capacity before enqueueing a whole message
and checks the accepted byte count; saturated logging is best effort and does not
wait for physical transmission.

`WebContent` adapts the application stores to `IHttpContent`. The endpoint
selects one stable body, prepares checksums from its bytes, and emits through
checked reads. WebApplication finishes the response copy and releases those
views before updating status counters. No body checksum promise or per-byte
body injection is required by the endpoint.

`WebApplication<R, T>` consumes frame-link capabilities. Livt.Net
`ResponseTransfer<T>` coordinates admission and retained completion; the
application keeps response RAM published throughout that lifecycle. It acquires
and copies only the captured prefix, then releases RX. Prepared replies live in a published
RAM provider. TX admission borrows that publication until a terminal completion;
backpressure and error handling never permit premature source reuse.

`WebApp` is the board composition root: it constructs the concrete EthernetLite
receiver, transmitter and driver and supplies them to `WebApplication`. The
wrapper retains the external AXI/UART pins. The new driver has Livt simulation
coverage only; the previous board baseline does not verify this refactoring.

## Namespaces

Production components live in `Livt.WebApp`. Tests use `Livt.WebApp.Tests`.

| Area | Components |
|---|---|
| Board composition | `WebApp` |
| Device-independent application | `WebApplication<R, T>` |
| Static content | `IndexHtmlStore`, `AboutHtmlStore`, `StatusHtmlStore` |
| Vendor wrapper | `board/webapp_wrapper.vhd` |

## Overview

`WebApplication` owns the application loop:

1. Acquire an available frame through `IFrameReceiver`.
2. Copy frame bytes into `Livt.Web.Http.NetworkEndpoint`.
3. Dispatch `/`, `/about`, and `/status` to the bound `WebContent` provider.
4. Prepare the complete response over that selected content.
5. Publish ARP, ICMP, TCP SYN-ACK or HTTP response data and submit it through
   `IFrameTransmitter`, retaining ownership until terminal completion.
6. Emit compact UART diagnostics for the banner and HTTP routes.

The Arty application contains only the web server and its diagnostics. The
packet-classification demo (rule, linear, and FFN) has been removed to reduce
hardware use. The board design also omits the RGB matrix IP and HUB75 pins.

The route slot meanings are owned by this package:

- route 1: `/`
- route 2: `/about`
- route 3: `/status`

## Supported Traffic

- Ethernet II
- ARP request handling for one local IPv4 address
- IPv4 packets with a fixed 20-byte header
- ICMP echo replies through `Livt.Net`
- TCP packets with a fixed 20-byte header
- HTTP/1.0 GET responses through `Livt.Web`
- One active TCP connection at a time

Out of scope: IPv6, UDP application traffic, TLS, QUIC, a full TCP/IP stack,
dynamic server-side content, and multiple simultaneous HTTP connections.

## Build and Test

```sh
livt test
livt build
```

The UART wire-level check and recorded migration results are described in
[`verification/README.md`](verification/README.md).

The final migration checks use the sibling Net and Web sources. Package versions
remain development identifiers; no registry publication or new board validation
is implied. Rebuild the generated IP package before any later board build.

The application capability test checks an independently expected complete ARP
reply and retains response storage through backpressure. Driver AXI handshakes,
RX/TX failures and coordinated reset are tested in Livt.Net. The obsolete,
unregistered `WebAppAxiIntegrationTest` used the former driver and synthetic
RX memory without FCS; it has been removed rather than counted as coverage.

The configured test list is defined in [`livt.toml`](livt.toml). The Vivado IP
metadata is also configured there under `[vendor.vivado.ip]`.

If generated test output needs to be refreshed without deleting synchronized
dependencies:

```sh
rm -rf out .livt/src.json .livt/ghdl
livt test
```

## Vivado Notes

Before the EthernetLite driver extraction, the WebApp-only package passed 16
release tests, Vivado IP catalog checks and native HDL elaboration. That historical
Arty bitstream used 37,028 LUTs (58.40%) with positive routed setup/hold slack.
These results do not verify the current driver or wrapper. See
[board build evidence](verification/arty-build-evidence.md) for timing,
programming results, and remaining warning follow-up.

The manifest targets the Arty A7-100T (`xc7a100tcsg324-1`) and packages
`eccelerators.com:samples:webapp:1.0`, as required by `livt-arty-a7-100t`.
The explicit [`webapp_wrapper`](board/webapp_wrapper.vhd) exposes `M_AXI`,
`Clk`, active-low `nRst`, `UartRx`, `UartTx`, and `EthernetFrameDetected`.
It supplies the Livt context with a 100 MHz clock and retains the 1024-cycle
application reset delay after the EthernetLite reset is released.

Default network settings are MAC `00:00:5E:00:FA:CE`, IP `10.0.0.2`, and
TCP port 80. Configure `LocalMacHex`, `LocalIpHex`, and `LocalPort` on the IP
instance as needed. UART uses 115200 baud, 8N1.

With Vivado and GHDL on PATH (or `LIVT_VIVADO_PATH` and `LIVT_GHDL_PATH`
pointing to their executables), run:

```sh
python3 scripts/package-ip.py
```

Set `LIVT` to a specific Livt executable if needed. The command builds release
HDL, runs Vivado IP packaging, and copies the generated package from
`.livt/vendor/package` to `package/`, applies explicit clock/reset/AXI metadata,
verifies the resulting IP in Vivado, and elaborates its HDL with GHDL. Generated files are ignored by Git.
The Arty project's existing IP repository path can then discover
`package/component.xml`; refresh its IP catalog or recreate the board project.
Rebuild the package after changing the app or its dependencies.

For a focused catalog check, run Vivado from a scratch directory:

```sh
vivado -mode batch -source /absolute/path/to/livt-web-app/verification/check-ip.tcl
```

This checks the IP identity, board pins, AXI master address space, clock, and reset.
Recorded results are in [packaging evidence](verification/packaging-evidence.md).
Packaging and catalog checks do not establish synthesis, timing closure, or
on-device behavior; those require building and testing the Arty board project.

## Development Notes

- Keep reusable packet and frame components in `Livt.Net`.
- Keep reusable HTTP endpoint behavior in `Livt.Web`.
- Keep application route meanings, page content, counters, UART text,
  and board/IP wiring in this package.
- Avoid exposing public functions from `WebApp` only for tests; prefer testing at
  the web endpoint or store boundary.
- Keep generated build output out of commits.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
