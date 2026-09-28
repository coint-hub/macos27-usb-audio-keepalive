label    := "com.coint.audio-keepalive"
template := label + ".plist"
bin      := home_directory() / ".local/bin/audio-keepalive"
plist    := home_directory() / "Library/LaunchAgents" / template
log      := home_directory() / "Library/Logs/audio-keepalive.log"

build:
    cd audio-keepalive && swift build -c release

install: build
    mkdir -p {{parent_directory(bin)}} {{parent_directory(plist)}}
    install -m 755 audio-keepalive/.build/release/AudioKeepalive {{bin}}
    sed -e 's|{label}|{{label}}|' -e 's|{bin}|{{bin}}|' -e 's|{log}|{{log}}|' {{template}} > {{plist}}
    plutil -lint {{plist}}
    launchctl bootout gui/$(id -u)/{{label}} 2>/dev/null || true
    launchctl bootstrap gui/$(id -u) {{plist}}

uninstall:
    launchctl bootout gui/$(id -u)/{{label}} 2>/dev/null || true
    rm -f {{plist}} {{bin}} {{log}}
