# Webhost
A simple way to host static websites.

## Getting Started
Follow along with the instructions below to get started.

### Dependencies
1. [rsync](https://formulae.brew.sh/formula/rsync)
1. [nginx](https://formulae.brew.sh/formula/nginx) [optional, for viewing the website locally]
  
### Prerequisites
1. Ubuntu server with ssh access to `root` (you can set one up through [DigitalOcean](https://www.digitalocean.com))
1. Domain name (e.g. github.com) (you can buy one through [Namecheap](https://www.namecheap.com) )
1. DNS configuration to point the domain to the server (you can follow [these instructions](https://www.digitalocean.com/community/tutorials/how-to-point-to-digitalocean-nameservers-from-common-domain-registrars) to configure DNS for DigitalOcean)  
  
Verify that your domain points to your server's IP with:
```
nslookup <host>
```
  
### Setup
Set up your server with the following commands:
  
**1. Clone the repo**
```
git clone git@github.com:christianbator/webhost.git
cd webhost
```  
  
**2. Add the webhost executable to your PATH**
```
export PATH="$PATH:$HOME/path/to/webhost/bin"
```  
  
**3. Configure the server**  
Create a user on the server named `webhost` with `sudo` privileges:
```
webhost create-user <host>
```  
  
Everything on the server will now be run from the `webhost` user. You're forced to create a new password - do so when prompted after running:
```
ssh webhost@<host>
```  
  
**4. Install [nginx](https://www.nginx.com/resources/wiki/) and [certbot](https://letsencrypt.org), then set up a firewall**
```
webhost install-deps <host>
```  
  
**5. Encrypt the traffic**
```
webhost install-certs <host>
```  
  
1. Enter the `webhost` password when prompted
1. For verification, select option 1: "Run an HTTP server locally"
1. Follow along with any other prompts  
  
**6. Enable the website**  
Update the nginx config remotely:
```
webhost update-nginx <host>
```
  
**6a. Update the nginx config locally [optional]**  
```
webhost update-nginx <host> (-l | --local) <port> [(-d | --directory) </local/content/dir>]
```  
  
Options:
- `-l | --local`: Required. Specify the local port after this (e.g. `--local 8000`)
- `-d | --directory`: Optional. If calling `webhost` from the parent of your website's `content` dir, ignore this. Otherwise, specify the local `content` dir to serve the website from.
  
**Setup Notes**
- The remote website is served as static content from nginx out of the
    `/home/webhost/<host>` directory
- Routing
  - All HTTP traffic is redirected to HTTPS
  - All www urls are redirected to non www
  - All trailing slash urls are rewritten to non trailing slash urls  
  
## Usage
Invoke `webhost` with no arguments to view the usage.  

1. Create your website's `content` directory in the following structure:
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
webhost push <host> [(-d | --local-content-dir) </local/content/dir>]
```  
  
Options:
- `-d | --local-content-dir` [optional]: If calling `webhost` from the parent of your website's `content` dir, ignore this. Otherwise, specify the local `content` dir to push to the server.  
  
**Content Notes**  
Fill in the `content/icons` directory with the following files so your site will automatically serve favicons and social media images:
```
favicon-0.png (64x64)
high-res-0.png (900x900)
```  
  
If you ever need to update them, bump the number to 1, 2, 3, etc.  
  
Happy hosting!
