#! /usr/bin/env zsh

# Associative array of list name and its URL alias
typeset -A BLOCKLISTS
BLOCKLISTS=(ads dgxtneitpuvgqqcpfulq spyware llvtlsjyoyiczbkjsxpf)

# Download location
LISTDIR=/var/cache/blocklists

#Only re-download if the cached version is older than this many days
REFRESH_DAYS=2

[ ! -d $LISTDIR ] && mkdir $LISTDIR

refresh_lists(){
    for iter in ${(k)BLOCKLISTS}; do
        # Download file only if cached version doesn't exist, or cached version is older than 1 day
         if [[ ! -f $LISTDIR/$iter ]] || (( $(date +%s) - $(stat --format=%Y $LISTDIR/$iter) > $REFRESH_DAYS*24*60*60 )); then    
            echo "Re-downloading $iter"
            wget -O - "http://list.iblocklist.com/?list=${BLOCKLISTS[$iter]}&fileformat=p2p&archiveformat=gz" | zcat > $LISTDIR/$iter   
        else
            echo "Using cached $iter"
        fi
    done
}

update_firewall(){
    for iter in ${(k)BLOCKLISTS}; do    
        ipset create -exist $iter hash:net maxelem 4294967295
        ipset flush $iter
        cut -d: -s -f2 /$LISTDIR/$iter | xargs -I {} ipset add $iter {}
        iptables -I INPUT -m set --match-set $iter src -j DROP
    done
}

flush_firewall(){
    for iter in ${(k)BLOCKLISTS}; do
        iptables -D INPUT -m set --match-set $iter src -j DROP || true
	ipset flush $iter
        ipset destroy $iter || true
    done    
}

case $1 in
    start|enable)
        refresh_lists
        update_firewall
        ;;
    stop|disable)
        flush_firewall
        ;;
    restart|reload)
        flush_firewall
        refresh_lists
        update_firewall    
        ;;
    *)
        echo "Must pass enable or disable"
        ;;
esac

