# Emulator configuration overlays

`windows/` and `linux/` hold D2K's per-emulator overlays: only the keys D2K
needs, never BIOS paths, game folders or saved window positions. On Linux,
`scripts/linux/configure-emulators.sh` applies them (`--check` verifies).

Which emulator each console uses, what every overlay key is for and the
problems behind them are in [`../emulators.md`](../emulators.md); the keyboard
scheme is in [`../controls.md`](../controls.md).
