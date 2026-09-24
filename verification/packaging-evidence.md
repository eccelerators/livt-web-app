# Arty IP packaging verification — 2026-09-21

**Result: the complete packaging command passes after compiler fix #493.**
The generated `package/component.xml` is ready for the Arty project to consume.

Target: `xc7a100tcsg324-1`, top `webapp_wrapper`, IP identifier
`eccelerators.com:samples:webapp:1.0`. Vivado 2026.1.

The actual `scripts/package-ip.py` command completed successfully using a fresh
snapshot of the installed compiler/extensions:

- CLI SHA-256: `3d3f8df67ee6df48149ae570ade127938b84280dd7fb2a37c5cd9c6b41a46ddc`.
- VHDL generator SHA-256: `76a868284a6c54229a9d8bb5abee6917f4cad5ec8eb23a91806dacf339217842`.
- Snapshot: `/tmp/livt-arty-fixed-toolchain`; executable `/tmp/livt-arty-fixed-cli`.

Verification covered:

- Fresh release HDL generation with the current sibling libraries.
- Vivado IP packaging and integrity checks.
- Explicit AXI4-Lite metadata, 100 MHz clock/reset association, and active-low reset.
- IP discovery through the app repository root, matching the Arty project.
- Instantiation of the required VLNV, board pins, and AXI master address space.
- Native GHDL VHDL-2008 elaboration of the copied package's `webapp_wrapper`.
- Existence of every referenced package file. All 84 packaged HDL files match
  the release output or handwritten wrapper byte for byte.

Logs:

- `/tmp/livt-arty-fixed-package.log`: complete successful packaging command.
- `.livt/vendor/vivado.log`: Vivado packaging.
- `.livt/vendor/board-ip.log`: metadata finalization and catalog/interface checks.
- `.livt/vendor/packaged-hdl.log`: successful native HDL elaboration.

The earlier package failed with undefined `FRAME_CAPACITY` references in callers
of Net parser methods with omitted default arguments. That package has now been
replaced and its failing elaboration check passes. The original reproduction
and compiler fix remain documented under issue #493 in the release trackers.

Vivado's unused-module, VHDL-2008 packaging, optional Product Guide, and reset
naming warnings remain. `nRst` is explicitly active-low; the interface check
verifies that setting despite the port not ending in `resetn`.

No board synthesis, placement/routing, timing closure, programming, or hardware
test was performed. These results establish packaging and HDL elaboration only.

CLI issue #500 remains open. The packaging command refreshes local path checksum
entries before building; registry checksums and version pins remain intact.
