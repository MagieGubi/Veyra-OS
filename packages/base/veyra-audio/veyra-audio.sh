# Systemweites PipeWire (veyra-audio): Programme finden den Server hier. Zugriff hat, wer in
# der Gruppe pipewire ist (oder root).
export PIPEWIRE_RUNTIME_DIR=/run/pipewire
export PULSE_SERVER=unix:/run/pipewire/pulse/native
