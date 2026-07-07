# Livt.WebApp Showcase Design

`Livt.WebApp` demonstrates a compact FPGA web endpoint assembled from reusable
Livt packages:

- `Livt.Net`: Ethernet, ARP, IPv4, ICMP, TCP, checksums, complete-frame I/O, and
  AXI EthernetLite boundary components.
- `Livt.Web`: HTTP GET recognition, response framing, minimal TCP/HTTP server
  state, and web endpoint dispatch.
- `Livt.WebApp`: static page stores, route meanings, UART diagnostics,
  classifier integration, counters, and Vivado top-level wiring.

The important boundary is that reusable protocol behavior stays below the app.
This package decides that route 1 is `/`, route 2 is `/about`, and route 3 is
`/status`; `Livt.Web.Http` only sees route slots and response body metadata.

## Frame Flow

1. `WebApp` polls `Livt.Net.EthernetFrameIo` for a complete received frame.
2. The frame is copied into `Livt.Web.Http.NetworkEndpoint`.
3. The same frame is passed through the rule, linear, and FFN frame classifiers.
4. `NetworkEndpoint` selects ARP, ICMP, TCP SYN-ACK, or HTTP response behavior.
5. For HTTP body positions, `WebApp` supplies bytes from `IndexHtmlStore`,
   `AboutHtmlStore`, or `StatusHtmlStore`.
6. Response bytes are written back into `EthernetFrameIo` for the platform
   adapter to transmit.

## Application State

`StatusHtmlStore` receives counters for ARP, ICMP, SYN, root, about, and status
activity. `WebApp` updates those counters after each handled frame and refreshes
route 3 body metadata before response generation.

UART output is intentionally diagnostic: a startup banner, route hits, and a
compact classifier summary line.

## Hardware Boundary

`WebApp` is the Livt top-level component. The checked-in VHDL wrapper exposes
the generated AXI EthernetLite master and UART ports in the shape expected by
the Vivado IP packaging configuration in `livt.toml`.

The current frame I/O path is still complete-frame oriented. A board-specific
adapter can replace or wrap that boundary without moving HTTP route meaning or
static content into reusable protocol packages.
