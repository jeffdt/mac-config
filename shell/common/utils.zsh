# General aliases
alias act="source ./.venv/bin/activate"
alias dact="deactivate"
alias la='ls -a'
alias src="source ~/.zshrc"
alias brewup="brew update && brew upgrade"

# Utility functions
function b64() {
    echo "encoded: $(echo -n $1 | base64)"
    echo "decoded: $(echo $1 | base64 --decode)"
}

function kdo() {
    ps ax | grep -i docker | egrep -iv 'grep|com.docker.vmnetd' | awk '{print $1}' | xargs kill
}
