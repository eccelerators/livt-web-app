# Livt.WebApp

`Livt.WebApp` is a small FPGA web-application showcase built with the
[Livt](https://eccelerators.com/livt) hardware programming language. It wires reusable
networking and HTTP components into one top-level application that can receive
Ethernet frames, serve static HTML routes, report simple runtime counters over a
status page, and emit UART diagnostics.

The application is intentionally narrow: it demonstrates a fixed-function
connected FPGA design without an operating system or soft CPU. Reusable protocol
logic lives in `Livt.Net` and `Livt.Web`; this package owns the showcase content,
route meanings, classifier demo, UART logging, and Vivado IP top-level wiring.

## Package

```toml
[dependencies]
Livt.WebApp = "0.1.0"
```

`Livt.WebApp` depends on:

- `Livt.Web 0.1.0` for HTTP endpoint dispatch and response framing.
- `Livt.Net 0.26.0` for Ethernet, ARP, IPv4, ICMP, TCP, checksum, frame I/O,
  and AXI EthernetLite boundary components.
- `Livt.IO 0.1.0` for UART and memory primitives used directly by the
  application.
- `Livt.Math 0.3.1` and `EthernetFrameClassifier 0.1.0` for the
  frame-classification demo.

## Namespaces

Production components live in `Livt.WebApp`. Tests use `Livt.WebApp.Tests`.

| Area | Components |
|---|---|
| Top level | `WebApp` |
| Static content | `IndexHtmlStore`, `AboutHtmlStore`, `StatusHtmlStore` |
| Vendor wrapper | `Livt.WebApp.WebApp.Wrapper.vhd` |

## Overview

`WebApp` owns the application loop:

1. Poll `Livt.Net.EthernetFrameIo` for a received frame.
2. Copy frame bytes into `Livt.Web.Http.NetworkEndpoint`.
3. Classify the frame with the rule, linear, and FFN classifiers.
4. Configure `Livt.Web.Http` route body metadata for `/`, `/about`, and
   `/status`.
5. Select static response bytes from the application-owned stores.
6. Write ARP, ICMP, TCP SYN-ACK, or HTTP response bytes back through
   `EthernetFrameIo`.
7. Emit compact UART diagnostics for banner, route, and classifier activity.

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

The configured test list is defined in [`livt.toml`](livt.toml). The Vivado IP
metadata is also configured there under `[vendor.vivado.ip]`.

If generated test output needs to be refreshed without deleting synchronized
dependencies:

```sh
rm -rf out .livt/src.json .livt/ghdl
livt test
```

## Vivado Notes

The top-level Vivado IP component is `WebApp`, with wrapper top
`webapp_wrapper`.

If Vivado regenerates IP output products and reports that `integer_vector` or
`boolean_vector` is not declared in a generated `Livt.Lang.Package.vhd`, run
the project-specific VHDL preprocessing script from the Vivado Tcl console.

## Development Notes

- Keep reusable packet and frame components in `Livt.Net`.
- Keep reusable HTTP endpoint behavior in `Livt.Web`.
- Keep application route meanings, page content, counters, UART text, classifier
  integration, and board/IP wiring in this package.
- Avoid exposing public functions from `WebApp` only for tests; prefer testing at
  the web endpoint or store boundary.
- Keep generated build output out of commits.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
