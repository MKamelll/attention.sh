#!/usr/bin/bash

HELP="
    attention <flags> <app_name>
    --track-fullscreen  Disable power management if the app is fullscreen
    --track-audio       Disable power management if the app is playing audio and assuming video
"

app_name=""
track_fullscreen="false"
track_audio="false"

if [[ "$#" -ne "2" ]]; then
    echo "$HELP"
    exit 1
fi

for arg in "$@"; do
    if [[ "$arg" == "--track-fullscreen" ]]; then
        echo "We are tracking fullscreen.."
        track_fullscreen="true"
    elif [[ "$arg" == "--track-audio" ]]; then
        echo "We are tracking audio.."
        track_audio="true"
    else
        app_name="$arg"
    fi
done    

# flags
last_screen_blanking_state="on"
last_fullscreen_state="no_fullscreen"
last_track_audio_state="no"

create_entry_box() {
    yad --entry 
}

launch_app() {
    "$app_name" &> /dev/null &
    script_pid=$!
}

wait_for_window_to_show_up() {
    while ! wmctrl -lp | grep -q "$script_pid"; do
        sleep 0.2
    done
}

is_window_closed() {
    if ! wmctrl -lp | grep -q "$script_pid"; then
        echo "$app_name window is gone.."
        echo "shutting down."
        exit 0
    fi
}

launch_app
wait_for_window_to_show_up

app_id=$(wmctrl -l | grep -ie "$app_name" | awk '{print $0}')

is_fullscreen() { 
    is_it_full_screen=$(xprop -id "$app_id" | grep -ie "_NET_WM_STATE(ATOM) = _NET_WM_STATE_FULLSCREEN")
    echo "$?"
}

is_playing_audio() {
    result=""
    audio_outputs_registered=$(pactl list sink-inputs)
    does_the_app_registering_an_audio_output=$(echo "$audio_outputs_registered" | grep -ie "$app_name")
    result+="$?"
    
    is_the_audio_player_open=$(echo "$audio_outputs_registered" | grep -ie "stream.is-live = \"true\"")
    result+="$?"
    
    is_the_audio_playing=$(echo "$audio_outputs_registered" | grep -ie "Corked: no")
    result+="$?"
    
    if [[ "$result" == "000" ]]; then
        echo "0"
    else
        echo "1"
    fi
}

turn_off_screen_blanking() {
    if [ "$last_screen_blanking_state" == "on" ]; then
        echo "Turning screen blanking off.."
        notify-send "⚠️ Power Management is inhibited by $app_name"
        xset -dpms  # disable DPMS (Energy Star) aka power manager
        last_screen_blanking_state="off"
    fi
}

turn_on_screen_blanking() {
    if [ "$last_screen_blanking_state" == "off" ]; then
        echo "Turning screen blanking on.."
        notify-send "⚠️ Power Management is back to normal"
        xset +dpms
        last_screen_blanking_state="on"
    fi
}

we_are_tracking_fullscreen() {

    if [[ "$(is_fullscreen)" == "0" ]]; then
        if [[ "$last_fullscreen_state" == "no_fullscreen" ]]; then
            echo "$app_name is now fullscreen.."
            last_fullscreen_state="fullscreen"
            turn_off_screen_blanking
        fi
   else
       if [[ "$last_fullscreen_state" == "fullscreen" ]]; then
           echo "$app_name is no longer fullscreen.."
           last_fullscreen_state="no_fullscreen"
           turn_on_screen_blanking
       fi
    fi 
}

we_are_tracking_audio() {
    
    if [[ "$(is_playing_audio)" == "0" ]]; then
        if [[ "$last_track_audio_state" == "no" ]]; then
            echo "$app_name is now playing audio.."
            last_track_audio_state="yes"
            turn_off_screen_blanking
        fi
   else
       if [[ "$last_track_audio_state" == "yes" ]]; then
           turn_on_screen_blanking
           echo "$app_name is no longer playing audio.."
           last_track_audio_state="no"
       fi
    fi 
}

while true; do
    is_window_closed
    if [[ "$track_fullscreen" == "true" ]]; then
        we_are_tracking_fullscreen
    elif [[ "$track_audio" == "true" ]]; then
        we_are_tracking_audio
    fi
   sleep 1
done
