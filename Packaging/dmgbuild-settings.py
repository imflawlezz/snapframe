# dmgbuild settings for Snapframe installer image.
# Invoked by Scripts/make-dmg.sh — paths are injected via -D defines.
#
# Visible icons (left → right):
#   Snapframe.app · Applications · Quarantine.command
# Background is stored as hidden ".background.png".
#
# Figma: export PNG at background_width × background_height, save as
# Packaging/dmg-background.png, then re-run make-dmg.sh.
# Window size follows the PNG. Current art: 720×480.
# Icon centers: (126, 224), (360, 224), (594, 224).

import os
import subprocess

application = defines.get("app", "dist/Snapframe.app")
quarantine = defines.get("quarantine", "Packaging/Quarantine.command")
badge_icon = None

files = [application, quarantine]

symlinks = {"Applications": "/Applications"}

background = defines.get("background", "Packaging/dmg-background.png")

background_width = 720
background_height = 480
if os.path.isfile(background):
    try:
        out = subprocess.check_output(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", background],
            text=True,
        )
        for line in out.splitlines():
            if "pixelWidth:" in line:
                background_width = int(line.split(":")[-1].strip())
            elif "pixelHeight:" in line:
                background_height = int(line.split(":")[-1].strip())
    except (OSError, ValueError, subprocess.CalledProcessError):
        pass

window_rect = ((200, 120), (background_width, background_height))
icon_size = 120
text_size = 12
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 0

arrange_by = None

icon_locations = {
    os.path.basename(application.rstrip("/")): (126, 224),
    "Applications": (360, 224),
    os.path.basename(quarantine): (594, 224),
}
