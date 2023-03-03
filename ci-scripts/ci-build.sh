#!/bin/bash -e
# shellcheck disable=SC2154,SC1091

. "$CIRCLE_WORKING_DIRECTORY"/.env

signal_hosts(){
    set +e
    for host in $DISTCC_HOSTS; do
        [ "$host" = 'localhost' ] && continue
        printf 'Sending done signal to %s\n' "${host%:*}"
        echo 'done' | nc -w 10 "${host%:*}" 40001
    done
}

case "$bn" in
    *-parallel|main)
        DISTCC_PORT='40000'
        DISTCC_CIDR='172.0.0.0/8'

        case "$CIRCLE_NODE_INDEX" in
            0)
                DISTCC_HOSTS='localhost'
                step=1
                while [ "$step" -lt "$CIRCLE_NODE_TOTAL" ]; do
                    peerhn="mereci-${CIRCLE_BUILD_NUM}-${CIRCLE_NODE_TOTAL}-${step}.tail94b04.ts.net"
                    peerip=$(dig +short "$peerhn")
                    until [ -n "$peerip" ]; do
                        printf 'Waiting for DNS to resolve for %s. Sleeping for 5s...\n' "$peerhn"
                        sleep 5
                        peerip=$(dig +short "$peerhn")
                    done
                    DISTCC_HOSTS="${DISTCC_HOSTS} ${peerip}:${DISTCC_PORT}"
                    step=$((step + 1))
                done
                cat >.build-env <<-EOF
				DISTCC_HOSTS=$DISTCC_HOSTS
				CC=/usr/lib/distcc/cc
				CXX=/usr/lib/distcc/c++
				EOF
                trap signal_hosts EXIT
                for pkg in "${pkgs[@]}"; do
                    MEREDIR="$(pwd)/mere-build" ./ci-scripts/buildpkg.sh "$pkg"
                    # List built packages
                    find mere-build || printf 'No mere-build dir\n'
                done
                ;;
            *)
                printf 'Listening on port %s\n' "$DISTCC_PORT"
                docker run -t --rm \
                    -p "$DISTCC_PORT":"$DISTCC_PORT" -e DISTCC_PORT="$DISTCC_PORT" \
                    -e DISTCC_CIDR="$DISTCC_CIDR" mere/distcc &
                # Listen on this port for any input to "signal" build job is finished
                printf 'Listening for done signal on port 40001\n'
                nc -l -p 40001
                ;;

        esac
        ;;
    *)
        for pkg in "${pkgs[@]}"; do
            MEREDIR="$(pwd)/mere-build" ./ci-scripts/buildpkg.sh "$pkg"
            # List built packages
            find mere-build || printf 'No mere-build dir\n'
        done
        ;;
esac
