# BASE64
function b64() {
    echo "encoded: $(echo -n $1 | base64)"
    echo "decoded: $(echo $1 | base64 --decode)"
}

# DOCKER
function kdo() {
    ps ax | grep -i docker | egrep -iv 'grep|com.docker.vmnetd' | awk '{print $1}' | xargs kill
}
