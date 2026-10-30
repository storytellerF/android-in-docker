ARG RUNTIME_IMAGE
FROM ${RUNTIME_IMAGE}
# Exercise the real entry point without SDK downloads or emulator execution.
COPY --chown=1000:1000 tests/fixtures/android-disabled.supervisord.conf /home/debian/supervisor/conf.d/android.supervisord.conf
