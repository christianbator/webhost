# Webhost
A simple way to host static websites.

## Getting Started
Follow along with the instructions below to get started.

### Dependencies
Install these with either apt or Homebrew if they aren't installed:
1. [zsh](https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH)
1. [gnu-getopt](https://formulae.brew.sh/formula/gnu-getopt)
1. [rsync](https://formulae.brew.sh/formula/rsync)
1. [Optional] [nginx](https://formulae.brew.sh/formula/nginx) (for viewing the website locally)
  
### Prerequisites
1. Ubuntu server with ssh access to `root` (you can set one up through [DigitalOcean](https://www.digitalocean.com/docs/droplets/how-to/create/))
1. Domain name (e.g. github.com) (you can buy one through [Namecheap](https://www.namecheap.com) )
1. DNS configuration to point the domain to the server (you can follow [these instructions](https://www.digitalocean.com/community/tutorials/how-to-point-to-digitalocean-nameservers-from-common-domain-registrars) to configure DNS for DigitalOcean)  
  
Verify that your domain points to your server's IP with:
```
nslookup {host}
```
  
### Setup
Set up your server with the following commands:
  
**1. Clone the repo**
```
git clone git@github.com:christianbator/webhost.git
cd webhost
```  
  
**2. Add the webhost executable to your PATH**
In `.zshrc`:
```
export PATH="$HOME/path/to/webhost/bin:$PATH"
```  
  
**3. Configure the server**  
Create a user named `webhost` with `sudo` privileges:
```
webhost create_user {host}
```  
  
Everything from now on will be run from the `webhost` user. You're forced to create a new password - do so when prompted after running:
```
ssh webhost@{host}
```  
  
**4. Install [nginx](https://www.nginx.com/resources/wiki/) and
  [certbot](https://letsencrypt.org), then set up a firewall**
```
webhost install_deps {host}
```  
  
**5. Encrypt the traffic**
```
webhost install_certs {host}
```  
  
1. Enter the webhost password when prompted
1. For verification, select option 1: "Run an HTTP server locally"
1. Follow along with any other prompts  
  
**6. Enable the website**  
Update the nginx config remotely:
```
webhost update_nginx {host} [(-a | --access-control) {path/to/access-control.conf}]
```
Options:
- [Optional] `-a | --access-control`: Specify an access control configuration (see the example access control file below)  
  
**6a. [Optional] Update the nginx config locally**  
```
webhost update_nginx {host} \
    (-l | --local) {port} [(-d | --local-content-dir) {/local/content/dir}] \
    [(-a | --access-control) {path/to/access-control.conf}]
```  
  
Options:
- `-l | --local`: Required, specify the local port after this (e.g. `--local 8000`)
- [Optional] `-d | --local-content-dir`: If calling `webhost` from the parent of your website's `content` dir, ignore this. Otherwise, specify the local `content` dir to serve the website from.
- [Optional] `-a | --access-control`: Specify an access control configuration (see the example access control file below)  
  
**6b. [Optional] Specify an `access-control.conf` file**  
You can specify an access control file to gate access to the website using standard nginx directives:
```nginx
  # Satisfy all directives for access
  satisfy all;

  # Allow a block of IPs (e.g. Wireguard VPN)
  allow 10.8.0.0/24;

  # Deny all other traffic
  deny all;
```  
  
**Setup Notes**
- The remote website is served as static content from nginx out of the
    `/home/webhost/{host}` directory
- Routing
  - All HTTP traffic is redirected to HTTPS
  - All www urls are redirected to non www
  - All trailing slash urls are rewritten to non trailing slash urls  
  
## Usage
Invoke `webhost` with no arguments to view the usage.  

1. Create your website's `content/` directory in the following structure:
```
content/        # Required
  sitemap.txt
  robots.txt
  pages/        # Required
    styles/
    fonts/
  icons/
  images/
```  
  
2. Push the website!
```
webhost push {host} [(-d | --local-content-dir) {/local/content/dir}]
```  
  
Options:
- [Optional] `-d | --local-content-dir`: If calling `webhost` from the parent of your website's `content` dir, ignore this. Otherwise, specify the local `content` dir to push to the server.  
  
**Content Notes**  
Fill in the `content/icons` directory with the following files
so your site will automatically serve favicons and social media images:
```
favicon-0.png (64x64)
high-res-0.png (900x900)
apple-touch-icon-0.png (180x180)
```  
  
If you ever need to update them, bump the number to 1, 2, 3, etc.  
  
Happy hosting!
