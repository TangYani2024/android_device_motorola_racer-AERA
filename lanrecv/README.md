# aera-lanrecv — LAN file receiver for AERA Recovery

A tiny static server (Rust, std-only, aarch64 musl static, ~0.5 MB) that
lets any phone on the same LAN send files to the device while it sits in
recovery — for when a PC is around but nobody wants to boot it.

## Use

1. In recovery, connect Wi-Fi (or join the phone's hotspot).
2. Open the recovery terminal and run:

   ```
   aera-lanrecv
   ```

   It prints the URL and the save directory, and accepts transfers while
   it runs. Ctrl-C stops it.
3. From the phone:
   - **Browser (always works):** open the printed `http://<ip>:53317/`
     page, pick files, send. The page also lists received files and can
     download them back.
   - **LocalSend app (best effort):** add the device manually by IP,
     port 53317. The v2 receive endpoints (`info`, `register`,
     `prepare-upload`, `upload`, `cancel`) are implemented over plain
     HTTP. If the app insists on HTTPS/fingerprint pairing, use the
     browser page instead.

Files land in `/sdcard/AERA/Downloads` when `/sdcard` is available,
otherwise in `/tmp/AERA-Downloads`. Name collisions get a ` (1)` suffix;
partial transfers are cleaned up automatically.

Trust model: the port is open only while the program runs — starting it
*is* the accept action. There is no authentication; use it on your own
LAN/hotspot only.

## Build

```sh
rustup target add aarch64-unknown-linux-musl   # .cargo/config.toml pins rust-lld
cargo build --release --target aarch64-unknown-linux-musl
# -> target/aarch64-unknown-linux-musl/release/aera-lanrecv
```

The binary in this tree lives at `recovery/root/system/bin/aera-lanrecv`
(mode 755). Source of truth: this directory (`src/main.rs`).
