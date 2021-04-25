#!/usr/bin/env bash
# ~/.profile > path to motd.sh

# Colors
export CA="\e[34m"  # Accent
export CO="\e[32m"  # Ok
export CW="\e[33m"  # Warning
export CE="\e[31m"  # Error
export CN="\e[0m"   # None

# Prints disk colors alerts
print_disk_alert () {
local out=""
    if [ "${percentage::-1}" -ge "85" ]; then
        out+="${CE}"
    elif [ "${percentage::-1}" -ge "65" ]; then
        out+="${CW}"
    elif [ "${percentage::-1}" -ge "35" ]; then
        out+="${CO}"
    else
        out+="${CA}"
    fi
    out+="$percentage${CN}"
    echo "$out"
}

# Max width used for components in second column
WIDTH=40

# Prints text as either acitve or inactive
# $1 - text to print
# $2 - literal "active" or "inactive"
print_status () {
    local out=""
    if [ "$2" == "active" ]; then
        out+="${CO}▲${CN}"
    else
        out+="${CE}▼${CN}"
    fi
    out+=" $1${CN}"
    echo "$out"
}

# Prints comma-separated arguments wrapped to the given width
# $1 - width to wrap to
# $2, $3, ... - values to print
print_wrap () {
    local width=$1
    shift
    local out=""
    local line_length=0
    for element in "$@"; do
        element="$element,"
        local visible_elelement="$(strip_ansi "$element")"
        local future_length=$(($line_length + ${#visible_elelement}))
        if [ $line_length -ne 0 ] && [ $future_length -gt $width ]; then
            out+="\n"
            line_length=0
        fi
        out+="$element "
        line_length=$(($line_length + ${#visible_elelement}))
    done
    [ -n "$out" ] && echo "${out::-2}"
}

# Strips ANSI color codes from given string
# $1 - text to strip
strip_ansi () {
    echo "$(echo -e "$1" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")"
}

# user@hostname
user="${CO}$(id -un)" ; hostname="$(hostname -f)${CN}"

# users
users="$(w | grep "pts" | wc -l)"

# os | os="$(lsb_release -s -d)"
source "/etc/os-release"

# kernel
kernel="$(uname -a | awk '{print $1,$3}')"

# packages
if type dpkg >/dev/null 2>&1; then
    packages="$(dpkg --get-selections | wc -l)"
    pack="dpkg"
elif type rpm >/dev/null 2>&1; then
    packages="$(rpm -qa | wc -l)"
    pack="rpm"
else
    packages="N/A"
fi
packages_out="$(echo $packages $pack)"

# lan ip
lan_ip="$(hostname --all-ip-addresses)"

# uptime
uptime="$(uptime -p | cut -d ' ' -f 2-)"

# load average | num_process="$(ps aux | wc -l)"
loadavg="$(cat /proc/loadavg | cut -d ' ' -f '1,2,3')"
cores_count="$(nproc)"

# memory + swap
freeh="$(free -h)"
freem="$(free -m)"
ram () {
    local memory total used available
    memory="$(awk '/Mem/ {print $2,$3,$7}' <<< $freeh)"
    IFS=" " read -r total used available <<< $memory
    echo "RAM - ${used::-1} used, ${available::-1} available / ${total::-1}"
}
ram_out="$(ram)"
swap () {
    local swap total used available
    # Return if no swap
    [ "$(awk '/Swap/ {print $2}' <<< $freem)" -eq 0 ] && echo "${CW}N/A${CN}" && return
    swap="$(awk '/Swap/ {print $2,$3,$4}' <<< $freeh)"
    IFS=" " read -r total used available <<< $swap
    echo "Swap - ${used::-1} used, ${available::-1} available / ${total::-1}"
}
swap_out="$(swap)"

# disks space
disks=($(lsblk --noheadings --list --output name))
all_disks_stats="$(df -h)"
disk_out=""
for disk in "${disks[@]}"; do
    device="/dev/${disk}"
    grep -q "$device\s" <<< $all_disks_stats || continue
    stats="$(awk -v pat="$disk" '$0~pat {print $2,$3,$4,$5,$6}' <<< $all_disks_stats)"
    IFS=" " read -r total used free percentage mountpoint <<< $stats
    label="- ($(print_disk_alert)) $disk ($mountpoint) - $used used, $free free / $total"
    disk_out+="$label\n"
done

# services
declare -A services
services["SSH"]="sshd"
services["NTP"]="ntp"
services["Nginx"]="nginx"
services["PHP-FPM"]="php7.3-fpm"
services["MariaDB"]="mysql"
services["Fail2Ban"]="fail2ban"
services["Seafile"]="seafile"
services["Prosody"]="prosody"
services["Coturn"]="coturn"
statuses=()
for key in "${!services[@]}"; do
    # systemctl is-active returns non-zero code if service is inactive
    set +e; status=$(systemctl is-active ${services[$key]}); set -e
    statuses+=("$(print_status "$key" "$status")")
done
services_out="$(print_wrap $WIDTH "${statuses[@]}")"

# updates
if type apt >/dev/null 2>&1; then
    #apt update >/dev/null 2>&1
    updates=$(apt list --upgradable 2>/dev/null | grep "может быть обновлён с" | wc -l)
elif type yum >/dev/null 2>&1; then
    updates=$(yum check-update | grep -E "updates|base|epel" | wc -l)
elif type dnf >/dev/null 2>&1; then
    updates=$(dnf check-update --quiet | grep -v "^$" | wc -l)
else
    updates="${CW}N/A${CN}"
fi
updates_out="$(echo $updates available)"

echo
echo "*------------------------------------------------------*"
echo -e "Logged as .... : $user@$hostname"
echo "Users ........ : $users online"
echo "OS ........... : $NAME $VERSION"
echo "Kernel ....... : $kernel"
echo "Packages ..... : $packages_out"
echo "LAN IP ....... : $lan_ip"
echo "Uptime ....... : $uptime"
echo "L.Average .... : $loadavg / cores: $cores_count"
echo "*------------------------------------------------------*"
echo "Memory ....... : ${ram_out}"
echo -e "Swap ..........: ${swap_out}"
echo "*------------------------------------------------------*"
echo -e "Disk space ... : \n${disk_out}"
echo "*------------------------------------------------------*"
echo -e "Services ..... : ${services_out}"
echo -e "Updates ...... : ${updates_out}"
echo
