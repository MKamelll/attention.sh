#!/usr/bin/bash

# metadata
app_name="$1"

# flags
last_screen_blanking_state="on"
last_fullscreen_state="no_fullscreen"


if [[ -z "$app_name" ]]; then
	echo "You did't provide a program to track"
	exit 1
fi

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

check_if_fullscreen() { 
    is_it_full_screen=$(xprop -id "$app_id" | grep -ie "_NET_WM_STATE(ATOM) = _NET_WM_STATE_FULLSCREEN")
    echo "$?"
}

turn_off_screen_blanking() {
    if [ "$last_screen_blanking_state" == "on" ]; then
        echo "Turning screen blanking off.."
        notify-send "⚠️ Power Inhibited" "Your system will not sleep while $app_name is running."
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

while true; do
    is_window_closed
    if [ "$(check_if_fullscreen)" == "0" ]; then
        if [ "$last_fullscreen_state" == "no_fullscreen" ]; then
            echo "$app_name is now fullscreen.."
            last_fullscreen_state="fullscreen"
            turn_off_screen_blanking
        fi
   else
       if [ "$last_fullscreen_state" == "fullscreen" ]; then
           turn_on_screen_blanking
           echo "Traking $app_name for fullscreen.."
           last_fullscreen_state="no_fullscreen"
       fi
    fi
    sleep 1
done
