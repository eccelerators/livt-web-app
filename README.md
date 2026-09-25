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

- `Livt.Web 1.0.0-dev` for HTTP endpoint dispatch and response framing.
- `Livt.Net 1.1.0-dev` for Ethernet, ARP, IPv4, ICMP, TCP, checksum, frame I/O,
  and AXI EthernetLite boundary components.
- `Livt.IO 1.2.0-dev` for UART and memory primitives used directly by the
  application.

The manifest resolves Net 1.1.0-dev, Web 1.0.0-dev, IO 1.2.0-dev and Base 1.1.0
from the package registry. Run `livt sync` to install the locked dependencies.

## UART and frame ownership

The application uses `IBufferedUart` backed by `BufferedUart<64, 128>` at the
default 115200 baud, 8 data bits, no parity, and one stop bit. Main is the sole
transmit producer. Logging checks free capacity before enqueueing a whole message
; saturated logging is best effort and does not
wait for physical transmission.

`WebRoutes<R>` declares GET routes using `HttpPath`, `Route`, `RouteChain` and
`StaticContent`. Each HTML store implements `IPacketData`; `/status` exposes six
mutable counter digits. Main updates them only after response readers stop,
so a selected body remains stable through checksum preparation and emission.
The stores no longer calculate or promise transport checksum sums.

`WebApplication<R, T>` binds `HttpServer` directly to the acquired receiver,
sharing one Ethernet/IPv4/TCP/request parser graph. There is no second RX copy.
The board receiver captures up to 1514 bytes; HTTP parsing is bounded to 1024
bytes and requires a complete request/header terminator in one TCP segment.

`ResponseTransfer<T>` retains the prepared response RAM through TX admission,
backpressure and terminal completion. RX and handler views also remain retained.
Successful delivery calls MarkEmitted/Complete; failure aborts after readers stop.
Only then are receive storage and status content reusable.

`ArtyWebApp` is the board composition root: it constructs the concrete EthernetLite
receiver, transmitter and driver and supplies them to `WebApplication`. The
wrapper retains the external AXI/UART pins. The migrated design passes focused simulation and complete HTTP checks on the
Arty A7-100T; see [board validation](verification/framework-board-validation.md).

## Namespaces

Production components live in `Livt.WebApp`. Tests use `Livt.WebApp.Tests`.

| Area | Components |
|---|---|
| Board composition | `ArtyWebApp` |
| Device-independent application | `WebApplication<R, T>` |
| Route declarations | `WebRoutes<R>`, `HomePath`, `AboutPath`, `StatusPath` |
| Body providers | `IndexHtmlStore`, `AboutHtmlStore`, `StatusHtmlStore` |
| Vendor wrapper | `board/webapp_wrapper.vhd` |

## Overview

`WebApplication` owns the application loop:

1. Acquire an available frame through `IFrameReceiver`.
2. Parse and dispatch through `HttpServer`, resuming Pending work with Poll.
3. Select an application GET handler or a shared 404/405 fallback.
4. Check and copy the complete prepared response into TX RAM.
5. Submit through `IFrameTransmitter` and retain all borrowed data until completion.
6. Release the graph and update counters for the next status snapshot.

The Arty application contains only the web server and its diagnostics. The
packet-classification demo (rule, linear, and FFN) has been removed to reduce
hardware use. The board design also omits the RGB matrix IP and HUB75 pins.

`HomePath`, `AboutPath` and `StatusPath` own the immutable URL bytes `/`, `/about`
and `/status`. The library has no numeric route slots or application URLs.

## Supported Traffic

- Ethernet II
- ARP request handling for one local IPv4 address
- IPv4 packets with a fixed 20-byte header
- ICMP echo replies through `Livt.Net`
- TCP packets with a fixed 20-byte header
- HTTP/1.0 GET responses through `Livt.Web`
- One active TCP connection at a time

Out of scope: IPv6, UDP application traffic, TLS, QUIC, a full TCP/IP stack,
request bodies, segmented requests, retransmission, and multiple simultaneous HTTP
connections. HEAD body suppression is not implemented; the demo declares GET only.
The HTTP response budget is 1460 bytes, including headers. Home/status bodies are
1373 bytes each and their complete responses are 1458 bytes; About is 1407 bytes
including headers. These limits are checked before transmission.

## Build and Test

```sh
livt test -r WebRoutesTest
livt test -r IndexHtmlStoreTest
livt test -r AboutHtmlStoreTest
livt test -r StatusHtmlStoreTest
livt build
```

Use component/test filters for focused iteration. Unfiltered `livt test` also
includes a very slow complete Home-frame case that can exceed the default
simulator timeout. See [migration verification](verification/framework-migration.md)
for the initial 184 passing focused checks, deferred full-frame simulation and the
command to resume the long case.

The UART wire-level check and recorded migration results are described in
[`verification/README.md`](verification/README.md).

The recorded migration and board checks used sibling Net and Web sources. The
manifest now selects registry packages; those earlier results do not independently
validate the published package contents. The migrated source package was built
and flashed successfully. Rebuild the generated IP package
after source changes before a later board build.

The application capability test checks an independently expected complete ARP
reply and retains response storage through backpressure. Driver AXI handshakes,
RX/TX failures and coordinated reset are tested in Livt.Net. The obsolete,
unregistered `WebAppAxiIntegrationTest` used the former driver and synthetic
RX memory without FCS; it has been removed rather than counted as coverage.

The configured test list is defined in [`livt.toml`](livt.toml). The Vivado IP
metadata is also configured there under `[vendor.vivado.ip]`.

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
- Avoid exposing public functions from `ArtyWebApp` only for tests; prefer testing at
  the web endpoint or store boundary.
- Keep generated build output out of commits.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
