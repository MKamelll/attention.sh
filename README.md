# attention.sh
Script to allow you to disable screen blanking during running an application in fullscreen mode on xfce

How to use:

```console
chmod +x attention.sh
./attention.sh <flag> <program you want to run in your $PATH>
```

`flag` could be `--track-fullscreen` or `--track-audio` if you're application plays audio, and could
be used with video also.

You could edit the app `.desktop` file and replace the command instead of the command in `Exec=<command>`.

I might be able to add a gui if i didn't get hit by a bus.
