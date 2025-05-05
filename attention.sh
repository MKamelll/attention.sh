#!/usr/bin/bash

app_name="$1"
reason_for_inhibition="$2"
screensaver_inhibition_cookie=""
power_management_inhibition_cookie=""

if [ -z "$app_name" ]; then
	echo "You did't provide a program to track"
	exit 1
fi

if [ -z "$reason_for_inhibition" ]; then
    echo "You didn't provide a reason for inhibition"
    exit 1
fi

app_id=$(wmctrl -l | grep -ie "$app_name" | awk '{print $0}')

check_if_fullscreen() { 
    is_it_full_screen=$(xprop -id "$app_id" | grep -ie "_NET_WM_STATE(ATOM) = _NET_WM_STATE_FULLSCREEN")
    echo "$?"
}

screensaver_service_available() {
    if gdbus call --session \
  --dest org.freedesktop.DBus \
  --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.NameHasOwner \
  "org.freedesktop.ScreenSaver" | grep -q "true"; then
        echo "Screensaver service is available.."
        return 0
    fi
    
    return 1
}

powermanagement_service_available() {
    if gdbus call --session \
  --dest org.freedesktop.DBus \
  --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.NameHasOwner \
  "org.freedesktop.PowerManagement" | grep -q "true"; then
        echo "PowerManagement service is available.."
        return 0
    fi
    
    return 1
}


inhibit_screensaver() {
    echo "Inhibiting screensaver.." >&2
    gdbus call --session \
  --dest org.freedesktop.ScreenSaver \
  --object-path /org/freedesktop/ScreenSaver \
  --method org.freedesktop.ScreenSaver.Inhibit \
  "$app_name" "$reason_for_inhibition"
   echo "done." >&2
}

inhibit_power_management() {
    echo "Inhibiting power management.." >&2
    gdbus call --session \
  --dest org.freedesktop.PowerManagement \
  --object-path /org/freedesktop/PowerManagement/Inhibit \
  --method org.freedesktop.PowerManagement.Inhibit.Inhibit \
  "$app_name" "$reason_for_inhibition"
   echo "done." >&2

}

uninhibit_screensaver() {
    if [ -n "$screensaver_inhibition_cookie" ]; then
        echo "Uninhibiting screensaver.." >&2
        gdbus call --session \
        --dest org.freedesktop.ScreenSaver \
        --object-path /org/freedesktop/ScreenSaver \
        --method org.freedesktop.ScreenSaver.UnInhibit \
        "$1"
        
        if [ "$?" == "0" ]; then
            echo "done." >&2
            screensaver_inhibition_cookie=""
        else
            echo "failed." >&2
        fi
    fi
}

uninhibit_power_management() {
    if [ -n "$power_management_inhibition_cookie" ]; then
        echo "Uninhibiting powermanagement.." >&2
        gdbus call --session \
        --dest org.freedesktop.PowerManagement \
        --object-path /org/freedesktop/PowerManagement/Inhibit \
        --method org.freedesktop.PowerManagement.Inhibit.UnInhibit \
        "$1"
        
        if [ "$?" == "0" ]; then
            echo "done." >&2
            power_management_inhibition_cookie=""
        else
            echo "failed." >&2
        fi
    fi

}

extract_cookie_number() {
    if [ -n "$1" ]; then
        echo "$1" | sed -n 's/.*uint32 \([0-9]\+\),.*/\1/p' | xargs
    fi
}

turn_off_screen_blanking() {
    xset -dpms       # disable DPMS (Energy Star) aka power manager
}

turn_on_screen_blanking() {
    xset +dpms
}

while true; do
    if [ "$(check_if_fullscreen)" == "0" ]; then
        echo "$app_name is fullscreen.."
        turn_off_screen_blanking
        #if [ -z "$screensaver_inhibition_cookie" ]; then
        #    if screensaver_service_available; then
        #        screensaver_cookie=$(inhibit_screensaver)
        #        screensaver_inhibition_cookie=$(extract_cookie_number "$screensaver_cookie")
        #    fi
        #fi
        
        #if [ -z "$power_management_inhibition_cookie" ]; then
        #    if powermanagement_service_available; then
        #        power_management_cookie=$(inhibit_power_management)
        #        power_management_inhibition_cookie=$(extract_cookie_number "$power_management_cookie")
        #        echo "$power_management_inhibition_cookie"
        #    fi
        #fi
    else
        #uninhibit_screensaver "$screensaver_inhibition_cookie"
        #uninhibit_power_management "$power_management_inhibition_cookie"
        turn_on_screen_blanking
        echo "Traking $app_name for fullscreen.."
    fi
    sleep 1
done
