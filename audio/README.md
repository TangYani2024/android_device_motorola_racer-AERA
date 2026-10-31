# aera-audio-bridge for racer: NOT PORTED YET (see device.mk).
#
# What it is: garnet's audio/ directory builds a small native bridge
# (aera_audio_bridge.cpp) that lets the recovery UI play sounds through
# the device's audio HAL. It is device-specific because it talks to the
# audio stack of that particular device.
#
# Racer's audio stack (from the LOS trees):
#   - Codec: Cirrus Logic Madera (snd-soc-madera, cs35l41 amps,
#     wm-adsp DSP) — see device BoardConfig.mk TARGET_MODULE_ALIASES
#     (audio_machine_lito, audio_wcd938x, audio_wsa881x, ...)
#   - Audio HAL: audio.primary.lito
#
# To port it: copy garnet's audio/Android.bp + aera_audio_bridge.cpp as
# a starting point and adapt the HAL interface names / mixer paths to
# racer (mixer_paths.xml in the LOS tree is the reference). This is
# optional for a first boot — recovery works without UI sounds.
# If audio turns out to be more trouble than it is worth, leave the
# package disabled permanently.
