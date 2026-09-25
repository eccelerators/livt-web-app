# Livt.WebApp Showcase Design

`Livt.WebApp` demonstrates a compact FPGA web endpoint assembled from reusable
Livt packages:

- `Livt.Net`: Ethernet, ARP, IPv4, ICMP, TCP, checksums, frame I/O and
  EthernetLite boundary components.
- `Livt.Web`: HTTP parsing, routing, response encoding and the bounded TCP adapter.
- `Livt.WebApp`: application routes, page stores, counters, UART diagnostics and
  the concrete Arty board composition.

`WebApplication<R, T>` owns the shared protocol graph and application lifecycle.
`ArtyWebApp` supplies its concrete EthernetLite receiver, transmitter, driver and
storage. Both are application-project components; reusable HTTP behavior lives
in Livt.Web.

## Frame Flow

1. The EthernetLite driver publishes received data through its receiver.
2. `WebApplication` acquires and retains that frame while its shared Ethernet,
   IPv4, TCP and HTTP components inspect it without a second capture buffer.
3. `HttpServer` handles the network response and dispatches HTTP through
   `WebRoutes`, which composes GET paths `/`, `/about` and `/status`.
4. Route handlers expose the corresponding HTML store; fallback responses handle
   missing paths and unsupported methods.
5. Response transfer publishes bytes through the RAM-backed transmitter.
6. RX and content views remain retained until transmission reaches a terminal
   outcome; storage is released only after its readers stop.

## Application State

`WebApplication` tracks prepared ARP, ICMP, SYN and page responses with six
hexadecimal counters. `StatusHtmlStore` receives their snapshot before response
preparation. Content stays stable while it is being served.

UART provides a startup banner and route diagnostics. There is no classifier in
this demo. HTML lives in internal memory; CSS and the logo load externally in the
browser. SPI flash asset serving is planned.

## Hardware Boundary

`ArtyWebApp` is the Livt top-level component selected in `livt.toml`. The checked-in
`webapp_wrapper` VHDL entity binds the generated `livt_webapp_artywebapp` entity
and exposes the existing AXI EthernetLite master and UART ports.

The package identity remains `Livt.WebApp`, and the Vivado IP identifier remains
`eccelerators.com:samples:webapp:1.0`. Repackage the IP after the component rename
before building the board; existing generated packages represent the previous
source version.
