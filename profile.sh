{
    env_file=$(mktemp)
    rm $env_file
    /app/.config/bastion/tunnel-env $env_file &

    while [ ! -f $env_file ];
    do
        sleep 1;
    done;
    . $env_file
    rm $env_file
}
