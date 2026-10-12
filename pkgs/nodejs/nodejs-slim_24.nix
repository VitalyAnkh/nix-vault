{
  stdenv,
  nodejs-slim_24,
}:
if !stdenv.hostPlatform.isDarwin then
  nodejs-slim_24
else
  nodejs-slim_24.overrideAttrs (old: {
    patches =
      (old.patches or [ ])
      ++ [
        # V8's generic std::hash specialization violates ODR and breaks worker FD
        # tracking with libc++ 21; Wrangler's build fails with EBADF. Backport the
        # upstream V8 fix into Node's bundled V8 (no Node version bump):
        # https://github.com/v8/v8/commit/65ce14d8731e929584344a0d65d6efd2296fa797
        ./v8-std-hash.patch
      ]
      # Test only: make the Happy Eyeballs fallback attempts fail on loopback rather
      # than depend on public addresses refusing the connection.
      ++ [ ./test-net-autoselectfamily-loopback.patch ];

    # Nixpkgs skips this worker FD regression in the main Darwin test suite.
    # Run it explicitly to verify the V8 fix while retaining all upstream checks.
    postCheck =
      (old.postCheck or "")
      + "\n"
      + ''
        ./out/Release/node test/parallel/test-worker-track-unmanaged-fds.js
      '';
  })
