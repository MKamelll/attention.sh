#!/usr/bin/python3
import subprocess
import sys
import time
from enum import Enum
from dataclasses import dataclass

class ScreenBlankingState(Enum):
    On = "on"
    Off = "off"

class FullscreenState(Enum):
    Fullscreen = "Fullscreen"
    Not_Fullscreen = "Not_Fullscreen"

class TrackAudioState(Enum):
    On = "on"
    Off = "off"

APP_NAME = ""
HELP = """
attention <flag> <app_name>
    Flags:
        --track-audio Track audio to diable power management
        --track-fullscreen Track fullscreen to disable power management
"""

@dataclass
class State:
    last_screen_blanking_state = ScreenBlankingState.On
    last_track_audio_state = TrackAudioState.Off
    last_fullscreen_state = FullscreenState.Not_Fullscreen


track_audio = False
track_fullscreen = False

if len(sys.argv) < 2:
    print(HELP)
    raise Exception("Not enough arguments provided")

for arg in sys.argv:
    if arg == "--track-audio":
        track_audio = True
    elif arg == "--track-fullscreen":
        track_fullscreen = True
    elif arg[0:2] != "--":
        APP_NAME = arg
    else:
        raise Exception("Not a supported flag")

def launch_app() -> int:
    process = subprocess.Popen([APP_NAME],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return process.pid

def wait_for_window_to_show_up(pid: int):
    while True:
        process = subprocess.Popen(["wmctrl", "-lp"],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, _ = process.communicate()
        if str(pid) in stdout and APP_NAME in stdout.lower():
            return
        time.sleep(0.2)

def is_window_closed(pid: int):
    process = subprocess.Popen(["wmctrl", "-lp"],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    stdout, _ = process.communicate()
    if not str(pid) in stdout and not APP_NAME in stdout.lower():
        print(f"{APP_NAME}'s window is closed..")
        print("Shutting down.")
        exit(0)

def get_app_id() -> str | None:
    process = subprocess.Popen(["wmctrl", "-lp"],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    stdout, _ = process.communicate()
    lines = stdout.splitlines()
    for line in lines:
        if APP_NAME in line.lower():
            return line.split(" ")[0]
    return None

def is_app_fullscreen(app_id: str) -> bool:
    process = subprocess.Popen(["xprop", "-id", app_id],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    stdout, _ = process.communicate()
    stdout_lower = stdout.lower()
    search_item_lower = "_NET_WM_STATE(ATOM) = _NET_WM_STATE_FULLSCREEN".lower()
    if search_item_lower in stdout_lower:
        return True
    return False

def is_playing_audio() -> bool:
    process = subprocess.Popen(["pactl", "list", "sink-inputs"],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    stdout, _ = process.communicate()
    
    stdout_lower = stdout.lower()
    if APP_NAME in stdout_lower and "stream.is-live = \"true\"" in stdout_lower and "corked: no" in stdout_lower:
        return True
    
    return False

def turn_off_screen_blanking(state: State):
    if state.last_screen_blanking_state == ScreenBlankingState.On:
        print("Turning off screen blanking..")
        subprocess.run(["notify-send", f"⚠️ Power Management is inhibited by {APP_NAME}"])
        subprocess.run(["xset", "-dpms"])
        state.last_screen_blanking_state = ScreenBlankingState.Off

def turn_on_screen_blanking(state: State):
    if state.last_screen_blanking_state == ScreenBlankingState.Off:
        print("Turning on screen blanking..")
        subprocess.run(["notify-send", f"⚠️ Power Management is back to normal"])
        state.last_screen_blanking_state = ScreenBlankingState.On

def we_are_tracking_fullscreen(app_id: str, state: State):
    if is_app_fullscreen(app_id):
        if state.last_fullscreen_state == FullscreenState.Not_Fullscreen:
            print(f"{APP_NAME} is now fullscreen..")
            state.last_fullscreen_state = FullscreenState.Fullscreen
            turn_off_screen_blanking(state)
    else:
        if state.last_fullscreen_state == FullscreenState.Fullscreen:
            print(f"{APP_NAME} is no longer fullscreen..")
            state.last_fullscreen_state = FullscreenState.Not_Fullscreen
            turn_on_screen_blanking(state)

def we_are_tracking_audio(state: State):
    if is_playing_audio():
        if state.last_track_audio_state == TrackAudioState.Off:
            print(f"{APP_NAME} is now playing audio..")
            state.last_track_audio_state = TrackAudioState.On
            turn_off_screen_blanking(state)
    else:
        if state.last_track_audio_state == TrackAudioState.On:
            print(f"{APP_NAME} is no longer playing audio..")
            state.last_track_audio_state = TrackAudioState.Off
            turn_on_screen_blanking(state)
        

pid = launch_app()
wait_for_window_to_show_up(pid)
app_id = get_app_id()
if app_id == None:
    raise Exception(f"Couldn't get {APP_NAME}'s id")

state = State()

while True:
    is_window_closed(pid)
    
    if track_audio:
        we_are_tracking_audio(state)
    elif track_fullscreen:
        we_are_tracking_fullscreen(app_id, state)
    
    time.sleep(1)
