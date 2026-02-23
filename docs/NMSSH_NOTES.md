# NMSSH Technical Notes

## Version Pinning

- Dependency manager: CocoaPods
- Pod: `NMSSH`
- Pinned version: `2.3.1` (exact)
- Why: prevent accidental behavior changes from floating updates in security-critical SFTP flows.

## Applied Cipher Patch

`Podfile` includes a `post_install` hook that patches `NMSSHSession.m` after `pod install`.

Patch location in NMSSH source:
- `NMSSHSession.m`, right after `libssh2_session_init_ex(...)`

Injected configuration:
- `LIBSSH2_METHOD_CRYPT_CS = aes128-ctr,aes256-ctr`
- `LIBSSH2_METHOD_CRYPT_SC = aes128-ctr,aes256-ctr`

Purpose:
- Prefer fast and broadly compatible CTR ciphers for current libssh2/NMSSH builds.
- Reduce handshake/negotiation failures observed with some servers.

## Operational Guidance

- If Pods are reinstalled or cleaned, rerun `pod install` so the patch is re-applied.
- Keep SFTP connection errors categorized (auth / timeout / host key / connection / file op) for better support diagnostics.
