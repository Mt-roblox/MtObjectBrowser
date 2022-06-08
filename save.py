# saves lua file to plugins folder
# does not reload plugin after copying

# windows version

from shutil import copy
from pathlib import Path

NAME = "MtObjectBrowser" # name of lua file

HOME = str(Path.home())+"\\" # home directory
DEST = HOME+"AppData\\Local\\Roblox\\Plugins\\" # plugins folder

if __name__ == "__main__":
    print(f"Copying {NAME}.lua to {DEST}")
    copy(f".\\{NAME}.lua", DEST)
    print(f"Success! Reload the plugin in roblox studio using the plugin debug service before testing.")