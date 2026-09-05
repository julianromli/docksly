# dmgbuild settings. Paths are filled by build-tester-dmg.sh via defines.
# Window size must match scripts/generate_dmg_background.swift (660 × 420).
# Use a volume name that Finder has not cached from an earlier unstyled image.

format = "UDZO"
filesystem = "HFS+"
compression_level = 9
files = [defines["app"]]
symlinks = {"Applications": "/Applications"}
hide_extensions = ["Docksly.app"]
hide = [".background.png"]

icon_locations = {
    "Docksly.app": (168, 200),
    "Applications": (492, 200),
}

background = defines["background"]
window_rect = ((280, 280), (660, 420))
default_view = "icon-view"

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 0
show_icon_preview = False

include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 12
icon_size = 80


def create_hook(mount_point, options):
    import os
    import subprocess

    background_file = os.path.join(mount_point, ".background.png")
    if os.path.exists(background_file):
        subprocess.call(["/usr/bin/SetFile", "-a", "V", background_file])
        subprocess.call(["/usr/bin/chflags", "hidden", background_file])
