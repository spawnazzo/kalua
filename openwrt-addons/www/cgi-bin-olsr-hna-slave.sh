#!/bin/sh
. /tmp/loader

knowing_hna_already()
{
	local funcname="knowing_hna_already"
	local netaddr="$1"
	local netmask="$( _net cidr2mask "$2" )"
	local i=0

	while true; do
		case "$( uci get olsrd.@Hna4[$i].netaddr)/$( uci get olsrd.@Hna4[$i].netmask )" in
			"$netaddr/$netmask")
				_log do $funcname daemon info "already know: $netaddr/$netmask"
				return 0
			;;
			"/")
				_log do $funcname daemon info "new hna: $netaddr/$netmask"
				return 1
			;;
		esac

		i=$(( $i + 1 ))
	done
}

hna_add()
{
	local netaddr="$1"
	local netmask="$( _net cidr2mask "$2" )"
	local token="$( uci add olsrd Hna4 )"

	uci set olsrd.$token.netaddr="$netaddr"
	uci set olsrd.$token.netmask="$netmask"
}

add_static_routes()
{
	local ip="$1"
	local netaddr="$2"
	local netmask="$3"
	local dev="$4"

	ip route add $netaddr/$netmask via $ip dev $dev metric 1 onlink
}

eval $( _http query_string_sanitize )

case "$( ip route list exact $netaddr/$netmask | fgrep " via $REMOTE_ADDR " )" in
	*" dev $LANDEV "*)
		dev2slave="$LANDEV"
	;;
	*" dev $WANDEV "*)
		dev2slave="$WANDEV"
	;;
esac

[ -n "$dev2slave" ] && {
	ERROR="OK"

	knowing_hna_already "$netaddr" "$netmask" || {
		hna_add "$netaddr" "$netmask"
		add_static_routes "$REMOTE_ADDR" "$netaddr" "$netmask" "$dev2slave"
		_olsr daemon restart "becoming hna-master for $REMOTE_ADDR: $netaddr/$netmask"
	}
}

_http header_mimetype_output "text/html"
echo "${ERROR:=ERROR}"
_log do htmlout daemon info "errorcode: $ERROR for IP: $REMOTE_ADDR"