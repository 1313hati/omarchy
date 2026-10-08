# The platform packages' own setup, last so it builds on every other leaf
# (omarchy-lifecycle-dispatch setup-boot and setup-system, see
# docs/lifecycle-dispatch.md): the boot package's first, then the runtime
# package's. A no-op where the platform registers none.
omarchy-lifecycle-dispatch setup-boot
omarchy-lifecycle-dispatch setup-system
