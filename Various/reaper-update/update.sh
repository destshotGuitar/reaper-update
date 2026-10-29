#!/bin/bash
# Helper for "Update REAPER" on Linux and macOS.
#
#   update.sh check <platform>            print the latest REAPER version on reaper.fm
#   update.sh install <platform> <dir>    wait for REAPER to quit, download and install
#                                         the latest version into <dir>, start REAPER again
#
# <platform>: linux-x86_64, linux-aarch64, linux-armv7l, linux-i686, mac
# <dir>: REAPER's executable folder (reaper.GetExePath())
set -uo pipefail

MODE=${1:-}
PLATFORM=${2:-}
EXE_DIR=${3:-}
WAIT_SEC=300

if [ "$(uname)" = Darwin ]; then
	IS_MAC=1
	PROCESS=REAPER
	LOG=~/Library/Logs/reaper-update.log
else
	IS_MAC=0
	PROCESS=reaper
	LOG=${XDG_CACHE_HOME:-$HOME/.cache}/reaper-update.log
fi

case $PLATFORM in
	mac) FILE_RE='reaper[0-9]+_universal\.dmg' ;;
	linux-*) FILE_RE="reaper[0-9]+_linux_${PLATFORM#linux-}\\.tar\\.xz" ;;
	*) echo "unknown platform: $PLATFORM"; exit 2 ;;
esac

# Programs started from REAPER don't see the proxy configured in the desktop
# settings, and reaper.fm may be unreachable without it.
setup_proxy() {
	[ -n "${https_proxy:-}${HTTPS_PROXY:-}" ] && return
	local host= port= s kread
	if ((IS_MAC)); then
		s=$(scutil --proxy 2>/dev/null) || return
		[ "$(awk '/HTTPSEnable/ {print $3}' <<<"$s")" = 1 ] || return
		host=$(awk '/HTTPSProxy/ {print $3}' <<<"$s")
		port=$(awk '/HTTPSPort/ {print $3}' <<<"$s")
	elif [ "$(gsettings get org.gnome.system.proxy mode 2>/dev/null)" = "'manual'" ]; then
		host=$(gsettings get org.gnome.system.proxy.https host | tr -d "'")
		port=$(gsettings get org.gnome.system.proxy.https port)
	else
		kread=$(command -v kreadconfig6 || command -v kreadconfig5) || return
		[ "$($kread --file kioslaverc --group 'Proxy Settings' --key ProxyType)" = 1 ] || return
		# "http://127.0.0.1 8080" or "http://127.0.0.1:8080"
		s=$($kread --file kioslaverc --group 'Proxy Settings' --key httpsProxy)
		s=${s#*://}
		host=${s%%[ :]*}
		port=${s##*[ :]}
	fi
	[ -n "$host" ] && [ "${port:-0}" != 0 ] && export https_proxy="http://$host:$port"
}

# "files/7.x/reaper784_linux_x86_64.tar.xz"
latest_path() {
	curl -fsSL --max-time 15 https://www.reaper.fm/download.php |
		grep -oE "files/[0-9]+\.x/$FILE_RE" | head -1
}

# files/7.x/reaper784_... -> 7.84
path_to_version() {
	local major n
	major=$(sed -E 's|^files/([0-9]+)\.x/.*|\1|' <<<"$1")
	n=$(sed -E 's|^.*/reaper([0-9]+)_.*|\1|' <<<"$1")
	echo "$major.${n#"$major"}"
}

log() { echo "$(date '+%F %T') $1" >>"$LOG"; }

notify() {
	log "$1"
	if ((IS_MAC)); then
		osascript -e "display notification \"$1\" with title \"REAPER\"" 2>/dev/null
	else
		notify-send -a REAPER -i cockos-reaper REAPER "$1" 2>/dev/null
	fi
}

fail() {
	log "ERROR: $1"
	if ((IS_MAC)); then
		osascript -e "display alert \"REAPER update failed\" message \"$1

Log: $LOG\" as critical" >/dev/null 2>&1
	elif command -v zenity >/dev/null; then
		zenity --error --title="REAPER update failed" --text="$1\n\nLog: $LOG" 2>/dev/null
	elif command -v kdialog >/dev/null; then
		kdialog --title "REAPER update failed" --error "$1\n\nLog: $LOG" 2>/dev/null
	else
		notify-send -u critical -a REAPER "REAPER update failed" "$1" 2>/dev/null
	fi
	exit 2
}

# Run a script as root if the target folder isn't writable.
run_install() {
	local script=$1 target=$2
	if [ -w "$target" ] && [ -w "$(dirname "$target")" ]; then
		/bin/bash "$script"
	elif ((IS_MAC)); then
		osascript -e "do shell script \"/bin/bash '$script'\" with administrator privileges"
	elif command -v pkexec >/dev/null; then
		pkexec /bin/bash "$script"
	else
		fail "$target is not writable and pkexec is not available"
	fi
}

install_linux() {
	local src="$tmp/reaper_linux_${PLATFORM#linux-}/REAPER"
	[ -x "$src/reaper" ] || fail "unexpected archive layout"
	[ -x "$EXE_DIR/reaper" ] || fail "REAPER not found in $EXE_DIR"
	printf 'cp -rf -- %q/. %q/\n' "$src" "$EXE_DIR" >"$tmp/do-install.sh"
	run_install "$tmp/do-install.sh" "$EXE_DIR" || fail "installation failed (password dialog cancelled?)"

	local installed
	installed=$(sed -nE '1s/^v([0-9.]+).*/\1/p' "$EXE_DIR/whatsnew.txt")
	[ "$installed" = "$latest" ] || fail "after installation the version is $installed, expected $latest"
}

start_linux() {
	# Prefer the menu launcher: it may carry options like "pw-jack -p 128".
	local f
	for f in "${XDG_DATA_HOME:-$HOME/.local/share}/applications/cockos-reaper.desktop" \
		/usr/local/share/applications/cockos-reaper.desktop \
		/usr/share/applications/cockos-reaper.desktop; do
		[ -f "$f" ] || continue
		if grep -q "^Exec=.*$EXE_DIR/reaper" "$f" && command -v gtk-launch >/dev/null; then
			gtk-launch cockos-reaper >/dev/null 2>&1 && return
		fi
		break
	done
	setsid "$EXE_DIR/reaper" >/dev/null 2>&1 </dev/null &
}

install_mac() {
	# GetExePath() is inside REAPER.app or the folder that holds it
	app=$EXE_DIR
	while [ "$app" != / ] && [[ $app != *.app ]]; do app=$(dirname "$app"); done
	[[ $app == *.app ]] || app="$EXE_DIR/REAPER.app"
	[ -d "$app" ] || fail "REAPER.app not found near $EXE_DIR"

	mkdir "$tmp/mnt"
	yes | hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$tmp/mnt" "$tmp/reaper.dmg" >/dev/null ||
		fail "could not open the disk image"
	[ -d "$tmp/mnt/REAPER.app" ] || { hdiutil detach -quiet "$tmp/mnt"; fail "REAPER.app not found in the disk image"; }

	printf 'rm -rf -- %q && ditto -- %q %q\n' "$app" "$tmp/mnt/REAPER.app" "$app" >"$tmp/do-install.sh"
	run_install "$tmp/do-install.sh" "$app"
	local rc=$?
	hdiutil detach -quiet "$tmp/mnt"
	((rc == 0)) || fail "installation failed (password dialog cancelled?)"

	log "installed version: $(defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null)"
}

setup_proxy
path=$(latest_path)
if [ -z "$path" ]; then
	echo "could not get the latest version from reaper.fm"
	[ "$MODE" = check ] && exit 2
	fail "could not get the latest version from reaper.fm"
fi
latest=$(path_to_version "$path")

if [ "$MODE" = check ]; then
	echo "$latest"
	exit 0
fi
[ "$MODE" = install ] && [ -n "$EXE_DIR" ] || { echo "usage: $0 check|install <platform> [<dir>]"; exit 2; }

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
log "=== updating $EXE_DIR to $latest"

if pgrep -x "$PROCESS" >/dev/null; then
	notify "Waiting for REAPER to quit to install $latest"
	for ((i = 0; i < WAIT_SEC; i++)); do
		pgrep -x "$PROCESS" >/dev/null || break
		sleep 1
	done
	pgrep -x "$PROCESS" >/dev/null && fail "REAPER did not quit within $((WAIT_SEC / 60)) minutes, update cancelled"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

notify "Downloading REAPER $latest"
if ((IS_MAC)); then archive="$tmp/reaper.dmg"; else archive="$tmp/reaper.tar.xz"; fi
curl -fsSL --max-time 600 --speed-limit 10000 --speed-time 30 -o "$archive" "https://www.reaper.fm/$path" ||
	fail "download failed: https://www.reaper.fm/$path"

notify "Installing REAPER $latest"
if ((IS_MAC)); then
	install_mac
	notify "REAPER updated to $latest"
	open "$app"
else
	tar -xf "$archive" -C "$tmp" || fail "the archive is damaged"
	install_linux
	notify "REAPER updated to $latest"
	start_linux
fi
