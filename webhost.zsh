#!/usr/bin/env zsh
set -euo pipefail

#
# Colors
#
cyan="\033[36m"
green="\033[32m"
bright_red="\033[91m"
reset="\033[0m"

#
# Usage
#
usage="> Usage:
    ${cyan}# Create remote \`webhost\` user to serve websites${reset}
    webhost create_user {host}

    ${cyan}# Configure remote server with nginx, ufw, and certbot${reset}
    webhost install_deps {host}

    ${cyan}# Request and install certificates for HTTPS${reset}
    webhost install_certs {host}

    ${cyan}# Update nginx locally or remotely to serve website${reset}
    webhost update_nginx {host} \\
        [(-l | --local) {port}] \\
        [(-d | --local-content-dir) {/local/content/dir}] \\
        [(-a | --access-control) {path/to/access-control.conf}]

    ${cyan}# Push website content to remote server${reset}
    webhost push {host} [(-d | --local-content-dir) {/local/content/dir}]"

#
# Arguments
#
scripts_dir=${0:a:h}

if [[ "$#" -lt 1 ]]; then
    echo -e "$usage"
    exit 1
elif [[ "$#" -lt 2 ]]; then
    echo -e "> ${bright_red}Error${reset}: too few arguments"
    echo -e "\n$usage"
    exit 1
fi

host=$2

#
# Create remote `webhost` user to serve websites
#
if [[ $1 == "create_user" ]]; then
    echo -e "> Creating webhost user for ${cyan}$host${reset} ..."

    ssh root@$host "bash -s" -- < $scripts_dir/webhost_setup.sh

    echo -e "\n> User creation successful ${green}✔${reset}, please login with ${cyan}ssh webhost@$host${reset} to set your password"

#
# Configure remote server with nginx, ufw, and certbot
#
elif [[ $1 == "install_deps" ]]; then
    echo -e "> Installing dependencies for ${cyan}$host${reset} ..."

    ssh -t webhost@$host "
        set -euo pipefail

        echo -e '> Updating packages ...'
        sudo apt-get update

        echo -e '> Installing nginx ...'
        sudo apt-get install -y nginx

        echo -e '> Allowing nginx traffic through firewall ...'
        sudo ufw allow 'Nginx Full'
        sudo ufw status

        echo -e '> Installing LetsEncrypt certbot ...'
        sudo snap install --classic certbot
    "

    echo -e "\n> Dependency installation successful ${green}✔${reset}"

#
# Request and install certificates for HTTPS
#
elif [[ $1 == "install_certs" ]]; then
    echo -e "> Installing certificates for ${cyan}$host${reset} ..."

    ssh -t webhost@$host "
        set -euo pipefail
        
        echo -e '> Stopping nginx ...'
        sudo systemctl stop nginx

        echo -e '> Requesting certificates for ${cyan}$host${reset} ...'
        sudo certbot certonly --nginx -d $host -d www.$host

        echo -e '> Restarting nginx ...'
        sudo killall nginx
        sudo systemctl restart nginx
        sudo systemctl status --no-pager nginx
    "

    echo -e "\n> Certificate installation successful ${green}✔${reset}"

#
# Update nginx locally or remotely to serve website
#
elif [[ $1 == "update_nginx" ]]; then
    # Set defaults
    local=false
    local_content_dir="$(pwd)/content"
    path_prefix=""
    access_control_conf="allow all;"

    # Shift to option arguments and invoke getopt
    valid_args=$(shift; shift; getopt -o l:d:a: --long local:,local-content-dir:,access-control: -- "$@")

    # Parse args and show usage if necessary
    update_nginx_usage="> Usage: webhost update_nginx {host} [(-l | --local) {port}] [(-d | --local-content-dir) {/local/content/dir}] [(-a | --access-control) {path/to/access-control.conf}]"

    if [[ $? -ne 0 ]]; then
        echo -e "> ${bright_red}Error${reset}: invalid options"
        echo -e "\n$update_nginx_usage"
        exit 1
    fi

    # Configure
    echo -e "> Configuring ${cyan}$host.conf${reset} ..."

    eval set -- "$valid_args"
    while [ : ]; do
      case "$1" in
        -l | --local)
            local=true
            local_port=$2
            echo -e "  > Local port: ${cyan}$local_port${reset}"
            shift 2
            ;;
        -d | --local-content-dir)
            if [[ $local != true ]]; then
                echo -e "> ${bright_red}Error${reset}: must specify [(-l | --local) {port}] option before [(-d | --local-content-dir) {/local/content/dir}]"
                echo -e "\n$update_nginx_usage"
                exit 1
            fi

            local_content_dir=$(echo "$2" | sed "s|\/*$||g")
            echo -e "  > Local content dir: ${cyan}$local_content_dir${reset}"
            shift 2
            ;;
        -a | --access-control)
            access_control_conf_file=$2
            access_control_conf=$(cat $access_control_conf_file)
            echo -e "  > Access control conf file: ${cyan}$access_control_conf_file${reset}"
            shift 2
            ;;
        --) 
            shift
            break
            ;;
      esac
    done

    config_dir=$scripts_dir/../config

    if [[ $local == true ]]; then
        server_conf=$(sed -e "s|{host}|$host|" -e "s|{port}|$local_port|" -e "s|{content_dir}|$local_content_dir|" $config_dir/server-local.conf)

        access_control_line=$(echo -e "$server_conf" | grep -n "{access_control}" | cut -d ":" -f 1)
        server_conf=$(echo -e "$server_conf" | head -n $(($access_control_line-1)); echo -e "$access_control_conf" | sed -e "s|^|    |"; echo -e "$server_conf" | tail -n +$(($access_control_line+1));)

        if [[ -z "$path_prefix" ]]; then
            server_conf=$(echo -e "$server_conf" | sed -e "s|{adjusted_file_route}|\$uri|")
        else
            server_conf=$(echo -e "$server_conf" | sed -e "s|{adjusted_file_route}|\$uri $path_prefix/\$uri|")
        fi

        echo -e "> Configuring ${cyan}nginx${reset} ..."
        nginx_conf=$(cat $config_dir/nginx-local.conf)

        echo -e "> Writing files to ${cyan}/opt/homebrew/etc/nginx${reset} ..."
        echo -e "  > ${cyan}$host.conf${reset}"

        echo -e "$server_conf" > /opt/homebrew/etc/nginx/servers/$host.conf

        echo -e "  > ${cyan}nginx.conf${reset}"
        echo -e "$nginx_conf" > /opt/homebrew/etc/nginx/nginx.conf

        echo -e "> Restarting nginx ..."
        brew services restart nginx

        echo -e "\n> Status nginx ..."
        brew services info nginx

        echo -e "\n> Nginx configuration successful ${green}✔${reset}"
    else
        server_conf=$(sed -e "s|{host}|$host|" $config_dir/server.conf)
        
        access_control_line=$(echo -e "$server_conf" | grep -n "{access_control}" | cut -d ":" -f 1)
        server_conf=$(echo -e "$server_conf" | head -n $(($access_control_line-1)); echo -e "$access_control_conf" | sed -e "s|^|    |"; echo -e "$server_conf" | tail -n +$(($access_control_line+1));)

        if [[ -z "$path_prefix" ]]; then
            server_conf=$(echo -e "$server_conf" | sed -e "s|{adjusted_file_route}|\$uri|")
        else
            server_conf=$(echo -e "$server_conf" | sed -e "s|{adjusted_file_route}|\$uri $path_prefix/\$uri|")
        fi

        echo -e "> Copying config files to ${cyan}webhost@$host:/home/webhost/tmp${reset} ..."
        ssh webhost@$host "mkdir -p tmp"

        echo -e "  > ${cyan}$host.conf${reset}"
        echo -e "$server_conf" | ssh webhost@$host -T "cat > /home/webhost/tmp/$host.conf"

        echo -e "  > ${cyan}nginx.conf${reset}"
        scp -q $config_dir/nginx.conf webhost@$host:/home/webhost/tmp

        echo -e "> Moving config files to ${cyan}webhost@$host:/etc/nginx${reset} ..."
        ssh -t webhost@$host "
            set -euo pipefail

            sudo echo -e '  > ${cyan}$host.conf${reset}'
            sudo mv tmp/$host.conf /etc/nginx/sites-available/$host.conf
            sudo ln -sf /etc/nginx/sites-available/$host.conf /etc/nginx/sites-enabled/$host.conf

            echo -e '  > ${cyan}nginx.conf${reset}'
            sudo mv tmp/nginx.conf /etc/nginx/nginx.conf
            
            rm -r tmp

            echo -e '> Restarting nginx ...'
            sudo systemctl start nginx
            sudo systemctl reload nginx

            echo -e '> Status nginx ...'
            sudo systemctl status --no-pager nginx
        "

        echo -e "\n> Nginx configuration successful ${green}✔${reset}"
    fi

#
# Push website content to remote server
#
elif [[ $1 == "push" ]]; then
    # Set defaults
    local_content_dir="content"

    # Shift to option arguments and invoke getopt
    valid_args=$(shift; shift; getopt -o d: --long local-content-dir: -- "$@")

    # Parse args and show usage if necessary
    push_usage="> Usage: webhost push {host} [(-d | --local-content-dir) {/local/content/dir}]"

    if [[ $? -ne 0 ]]; then
        echo -e "> ${bright_red}Error${reset}: invalid options"
        echo -e "\n$push_usage"
        exit 1
    fi

    eval set -- "$valid_args"
    while [ : ]; do
      case "$1" in
        -d | --local-content-dir)
            local_content_dir=$(echo "$2" | sed "s|\/*$||g")
            shift 2
            ;;
        --) 
            shift
            break
            ;;
      esac
    done

    # Remove trailing slashes
    local_content_dir=$(echo "$local_content_dir" | sed "s|\/*$||")

    echo -e "> Pushing ${cyan}$local_content_dir${reset} to ${cyan}webhost@$host:/home/webhost/$host/content${reset} ..."

    rsync --verbose \
        --recursive \
        --mkpath \
        --times \
        --delete-after \
        --delete-excluded \
        --compress \
        --human-readable \
        --exclude ".*" \
        $local_content_dir/ \
        webhost@$host:/home/webhost/$host/content

    echo -e "\n> Push successful ${green}✔${reset}"

#
# Unrecognized command
#
else
    echo -e "> ${bright_red}Error${reset}: unrecognized command $1"
    echo -e "\n$usage"
    exit 1
fi
