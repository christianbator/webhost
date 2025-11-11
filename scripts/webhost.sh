#!/usr/bin/env bash
#
# webhost.sh
# webhost
#
# Created by Christian Bator on 11/11/2025
#

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
usage="Usage:

    # Create remote \`webhost\` user to serve websites
    webhost create-user <host>

    # Configure remote server with nginx, ufw, and certbot
    webhost install-deps <host>

    # Request and install certificates for HTTPS
    webhost install-certs <host>

    # Update nginx locally or remotely to serve website
    webhost update-nginx <host> [(-l | --local) <port>] [(-d | --directory) </local/content/dir>]

    # Push website content to remote server
    webhost push <host> [(-d | --directory) </local/content/dir>]
"

#
# Arguments
#
scripts_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [[ "$#" -lt 1 ]]; then
    echo -e "$usage"
    exit 1
elif [[ "$#" -lt 2 ]]; then
    echo -e "${bright_red}Error${reset}: too few arguments"
    echo -e "\n$usage"
    exit 1
fi

command=$1
host=$2

#
# Create remote `webhost` user to serve websites
#
if [[ $1 == "create-user" ]]; then
    echo -e "Creating webhost user for ${cyan}$host${reset} ..."

    ssh root@$host "bash -s" -- < $scripts_dir/create-user.sh

    echo -e "\nUser creation successful ${green}✔${reset}, please login with ${cyan}ssh webhost@$host${reset} to set your password"

#
# Configure remote server with nginx, ufw, and certbot
#
elif [[ $command == "install-deps" ]]; then
    echo -e "Installing dependencies for ${cyan}$host${reset} ..."

    ssh -t webhost@$host "
        set -euo pipefail

        echo -e 'Updating packages ...'
        sudo apt-get update

        echo -e 'Installing nginx ...'
        sudo apt-get install -y nginx
        
        echo -e 'Allowing nginx traffic through firewall ...'
        sudo ufw allow 'Nginx Full'
        sudo ufw status

        echo -e 'Installing LetsEncrypt certbot ...'
        sudo snap install --classic certbot
    "

    echo -e "\nDependency installation successful ${green}✔${reset}"

#
# Request and install certificates for HTTPS
#
elif [[ $command == "install-certs" ]]; then
    echo -e "Installing certificates for ${cyan}$host${reset} ..."

    ssh -t webhost@$host "
        set -euo pipefail
        
        echo -e 'Stopping nginx ...'
        sudo systemctl stop nginx

        echo -e 'Requesting certificates for ${cyan}$host${reset} ...'
        sudo certbot certonly --nginx -d $host -d www.$host

        echo -e 'Restarting nginx ...'
        sudo killall nginx
        sudo systemctl restart nginx
        sudo systemctl status --no-pager nginx
    "

    echo -e "\nCertificate installation successful ${green}✔${reset}"

#
# Update nginx locally or remotely to serve website
#
elif [[ $command == "update-nginx" ]]; then
    echo -e "Configuring ${cyan}$host.conf${reset} ..."

    # Set defaults
    local=false
    local_port=""
    content_dir="$(pwd)/content"

    # Parse args and show usage if necessary
    update_nginx_usage="Usage: webhost update-nginx <host> [(-l | --local) <port>] [(-d | --directory) </local/content/dir>]"

    shift; shift
    if [[ $? -ne 0 ]]; then
        echo -e "${bright_red}Error${reset}: invalid options"
        echo -e "\n$update_nginx_usage"
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--local)
                if [ $# -lt 2 ] || [[ "$2" == -* ]]; then
                    echo -e "${bright_red}Error${reset}: invalid options"
                    echo -e "\n$update_nginx_usage"
                    exit 1
                fi

                local=true
                local_port="$2"
                
                echo -e "  Local port: ${cyan}$local_port${reset}"
                shift 2
                ;;
            -d|--directory)
                if [[ $local != true ]]; then
                    echo -e "${bright_red}Error${reset}: must specify [(-l | --local) <port>] option before [(-d | --directory) </local/content/dir>]"
                    exit 1
                fi

                if [ $# -lt 2 ] || [[ "$2" == -* ]]; then
                    echo -e "${bright_red}Error${reset}: invalid options"
                    echo -e "\n$update_nginx_usage"
                    exit 1
                fi
                
                content_dir="${2%/}"
                
                echo -e "  Local content dir: ${cyan}$content_dir${reset}"
                shift 2
                ;;
            --) shift; break ;;
            --*=*)
                echo -e "${bright_red}Error${reset}: invalid options"
                echo -e "\n$update_nginx_usage"
                exit 1
                ;;
            -*)
                echo -e "${bright_red}Error${reset}: invalid options"
                echo -e "\n$update_nginx_usage"
                exit 1
                ;;
            *)
                # No positional args expected after <host>
                break
                ;;
        esac
    done

    # Configure
    config_dir=$scripts_dir/../config

    if [[ $local == true ]]; then
        server_conf=$(sed -e "s|{host}|$host|" -e "s|{port}|$local_port|" -e "s|{content_dir}|$content_dir|" $config_dir/server-local.conf)

        echo -e "Configuring ${cyan}nginx${reset} ..."

        if [[ -d /opt/homebrew/etc/nginx ]]; then 
            prefix="/opt/homebrew"
            mkdir -p "$prefix/etc/nginx/sites-enabled"
        elif [[ -d /usr/local/etc/nginx ]]; then 
            prefix="/usr/local"
            mkdir -p "$prefix/etc/nginx/sites-enabled"
        elif [[ -d /etc/nginx ]]; then
            prefix=""
            sudo mkdir -p "$prefix/etc/nginx/sites-enabled"
        else
            echo -e "${bright_red}Error${reset}: failed to find nginx installation"
            exit 1
        fi
        
        nginx_conf=$(sed -e "s|{prefix}|$prefix|" $config_dir/nginx-local.conf)

        echo -e "Writing files to ${cyan}$prefix/etc/nginx${reset} ..."
        echo -e "  ${cyan}$host.conf${reset}"

        echo -e "$server_conf" > "$prefix/etc/nginx/sites-enabled/$host.conf"

        echo -e "  ${cyan}nginx.conf${reset}"
        echo -e "$nginx_conf" > "$prefix/etc/nginx/nginx.conf"

        echo -e "Restarting nginx ..."
        if command -v brew >/dev/null && brew services list 2>/dev/null | grep -q '^nginx'; then
            brew services restart nginx
        elif command -v systemctl >/dev/null && sudo systemctl list-units --type=service | grep -q nginx.service; then
            sudo systemctl start nginx
            sudo systemctl reload nginx
        else
            echo -e "${bright_red}Error${reset}: failed to find nginx restart command"
            exit 1
        fi

        echo -e "\nStatus nginx ..."
        if command -v brew >/dev/null && brew services list 2>/dev/null | grep -q '^nginx'; then
            brew services info nginx
        elif command -v systemctl >/div/null && sudo systemctl list-units --type=service | grep -q nginx.service; then
            sudo systemctl status --no-pager nginx
        else 
            echo -e "${bright_red}Error${reset}: failed to find nginx status command"
            exit 1
        fi

        echo -e "\nNginx configuration successful ${green}✔${reset}"
    else
        server_conf=$(sed -e "s|{host}|$host|" $config_dir/server.conf)

        echo -e "Copying config files to ${cyan}webhost@$host:/home/webhost/tmp${reset} ..."
        ssh webhost@$host "mkdir -p tmp"

        echo -e "  ${cyan}$host.conf${reset}"
        echo -e "$server_conf" | ssh webhost@$host -T "cat > /home/webhost/tmp/$host.conf"

        echo -e "  ${cyan}nginx.conf${reset}"
        scp -q $config_dir/nginx.conf webhost@$host:/home/webhost/tmp

        echo -e "Moving config files to ${cyan}webhost@$host:/etc/nginx${reset} ..."
        ssh -t webhost@$host "
            set -euo pipefail

            sudo echo -e '  ${cyan}$host.conf${reset}'
            sudo mv tmp/$host.conf /etc/nginx/sites-available/$host.conf
            sudo ln -sf /etc/nginx/sites-available/$host.conf /etc/nginx/sites-enabled/$host.conf

            echo -e '  ${cyan}nginx.conf${reset}'
            sudo mv tmp/nginx.conf /etc/nginx/nginx.conf
            
            rm -r tmp

            echo -e 'Restarting nginx ...'
            sudo systemctl start nginx
            sudo systemctl reload nginx

            echo -e 'Status nginx ...'
            sudo systemctl status --no-pager nginx
        "

        echo -e "\nNginx configuration successful ${green}✔${reset}"
    fi

#
# Push website content to remote server
#
elif [[ $command == "push" ]]; then
    # Set defaults
    content_dir="content"

    # Shift to option arguments
    shift; shift

    push_usage="Usage: webhost push <host> [(-d | --directory) </local/content/dir>]"

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--directory)
                if [ $# -lt 2 ] || [[ "$2" == -* ]]; then
                    echo -e "${bright_red}Error${reset}: invalid options"
                    echo -e "\n$push_usage"
                    exit 1
                fi
                
                # Strip trailing slashes
                content_dir="${2%/}"
                shift 2
                ;;
            --) shift; break ;;
            --*=*)
                echo -e "${bright_red}Error${reset}: invalid options"
                echo -e "\n$push_usage"
                exit 1
                ;;
            -*)
                echo -e "${bright_red}Error${reset}: invalid options"
                echo -e "\n$push_usage"
                exit 1
                ;;
            *)
                # No positional args here
                break
                ;;
        esac
    done

    # Push content
    echo -e "Pushing ${cyan}$content_dir${reset} to ${cyan}webhost@$host:/home/webhost/$host/content${reset} ..."

    rsync --verbose \
        --recursive \
        --mkpath \
        --times \
        --delete-after \
        --delete-excluded \
        --compress \
        --human-readable \
        --exclude ".*" \
        $content_dir/ \
        webhost@$host:/home/webhost/$host/content

    echo -e "\nPush successful ${green}✔${reset}"

#
# Unrecognized command
#
else
    echo -e "${bright_red}Error${reset}: unrecognized command $1"
    echo -e "\n$usage"
    exit 1
fi
