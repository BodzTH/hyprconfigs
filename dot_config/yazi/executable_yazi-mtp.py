#!/usr/bin/env python3
import os
import subprocess
import sys
import time
from urllib.parse import urlparse

def get_mtp_devices() -> list[dict[str, any]]:
    """Query and parse connected MTP/phone volumes from gio in a single pass."""
    try:
        output = subprocess.check_output(["gio", "mount", "-li"], text=True)
    except subprocess.CalledProcessError:
        return []

    mtp_volumes = []
    current_vol = None
    
    for line in output.splitlines():
        if not line.strip():
            continue
            
        if line.startswith("Volume("):
            # Start of a new volume block
            name = line.split(":", 1)[1].strip()
            current_vol = {
                "name": name,
                "is_mtp": False,
                "activation_root": None,
                "is_mounted": False
            }
        elif current_vol and line.startswith(" "):
            # Inside a volume block's details
            line_stripped = line.strip()
            if "GProxyVolumeMonitorMTP" in line_stripped:
                current_vol["is_mtp"] = True
            elif line_stripped.startswith("activation_root="):
                current_vol["activation_root"] = line_stripped.split("=", 1)[1].strip()
            elif "Mount(" in line_stripped:
                current_vol["is_mounted"] = True
        else:
            # End of volume details, save previous if it was an MTP volume
            if current_vol:
                if current_vol["is_mtp"] and current_vol["activation_root"]:
                    mtp_volumes.append(current_vol)
                current_vol = None
                
    if current_vol and current_vol["is_mtp"] and current_vol["activation_root"]:
        mtp_volumes.append(current_vol)
        
    return mtp_volumes

def notify(summary: str, body: str = "", icon: str = "phone") -> None:
    """Send a desktop notification using notify-send."""
    try:
        subprocess.run(["notify-send", "-i", icon, summary, body])
    except Exception:
        pass

def change_yazi_dir(target_path: str) -> None:
    """Command Yazi to change directory using the ya CLI."""
    yazi_id = os.environ.get("YAZI_ID")
    cmd = ["ya", "emit-to", str(yazi_id), "cd", target_path] if yazi_id else ["ya", "emit", "cd", target_path]
    try:
        subprocess.run(cmd, capture_output=True, text=True)
    except Exception:
        pass

def mount_all() -> bool:
    """Mount all detected MTP devices and navigate Yazi to their mount path."""
    volumes = get_mtp_devices()
    if not volumes:
        notify("MTP Mount", "No phone/MTP device detected.", icon="phone")
        return False

    uid = os.getuid()
    mounted_any = False
    
    for vol in volumes:
        name = vol["name"]
        root = vol["activation_root"]
        host = urlparse(root).netloc
        mount_path = f"/run/user/{uid}/gvfs/mtp:host={host}"

        # Fast-track: if already mounted and fully accessible, navigate immediately
        if vol["is_mounted"]:
            try:
                if os.path.exists(mount_path) and os.listdir(mount_path):
                    change_yazi_dir(mount_path)
                    mounted_any = True
                    continue
            except OSError:
                pass
        
        # Poll for mount creation and user authorization (up to 15 seconds)
        authorized = False
        prompt_shown = False
        
        for attempt in range(15):
            directory_exists = os.path.exists(mount_path)
            
            # Check if mount point is readable
            if directory_exists:
                try:
                    if os.listdir(mount_path):
                        authorized = True
                        break
                except OSError:
                    pass
            
            # Trigger/retry mount only if directory doesn't exist or on first attempt
            if not directory_exists or attempt == 0:
                try:
                    subprocess.run(["gio", "mount", root], capture_output=True, text=True)
                except Exception:
                    pass
            
            # Notify user to unlock and tap 'Allow' after 1 second if not yet authorized
            if attempt == 1 and not prompt_shown:
                notify("MTP Mount", f"Action Required: Please unlock {name} and tap 'Allow' to authorize access.", icon="phone")
                prompt_shown = True
            
            time.sleep(1)
            
        if authorized:
            notify("MTP Mount", f"Successfully mounted {name}.", icon="phone")
            change_yazi_dir(mount_path)
            mounted_any = True
        else:
            notify("MTP Mount", f"Mount timed out: Please unlock {name} and authorize access.", icon="dialog-error")
            
    if not mounted_any:
        change_yazi_dir(f"/run/user/{uid}/gvfs")
            
    return True

def unmount_all() -> None:
    """Unmount all currently mounted MTP volumes."""
    volumes = get_mtp_devices()
    mounted_volumes = [v for v in volumes if v["is_mounted"]]
    
    if not mounted_volumes:
        notify("MTP Unmount", "No mounted phone/MTP device found.", icon="phone")
        return

    for vol in mounted_volumes:
        name = vol["name"]
        root = vol["activation_root"]
        notify("MTP Unmount", f"Unmounting {name}...", icon="phone")
        try:
            res = subprocess.run(["gio", "mount", "-u", root], capture_output=True, text=True)
            if res.returncode == 0:
                notify("MTP Unmount", f"Successfully unmounted {name}.", icon="phone")
            else:
                notify("MTP Unmount", f"Failed to unmount {name}: {res.stderr.strip()}", icon="dialog-error")
        except Exception as e:
            notify("MTP Unmount", f"Failed to unmount {name}: {str(e)}", icon="dialog-error")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: yazi-mtp.py [mount|unmount]")
        sys.exit(1)
        
    cmd = sys.argv[1]
    if cmd == "mount":
        mount_all()
    elif cmd == "unmount":
        unmount_all()
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
