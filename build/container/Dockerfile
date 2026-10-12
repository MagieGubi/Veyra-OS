# Bootstrap-Host fuer Veyra: liefert nur die Werkzeuge, um die Cross-Toolchain zu bauen.
# Nichts aus diesem Container landet im fertigen Veyra-System.
# TODO (Reproduzierbarkeit): Image per Digest pinnen, sobald der erste CI-Lauf ihn ausgibt.
FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential bison gawk m4 texinfo python3 perl patch file bc \
      xz-utils zstd curl ca-certificates gnupg dirmngr \
 && rm -rf /var/lib/apt/lists/* \
 && ln -sf bash /bin/sh \
 && useradd -m -u 1000 veyra

ENV LC_ALL=C.UTF-8
