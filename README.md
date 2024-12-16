# Webhost
A simple way to host static websites.

## Getting Started
Follow along with the instructions below to get started.

### Dependencies
1. [zsh](https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH)
1. [gnu-getopt](https://formulae.brew.sh/formula/gnu-getopt)
1. [rsync](https://formulae.brew.sh/formula/rsync)
1. [nginx](https://formulae.brew.sh/formula/nginx) (optional: for viewing the website locally)

### Prerequisites
1. Ubuntu server with ssh access to `root`
  - You can set one up through [DigitalOcean](https://www.digitalocean.com/docs/droplets/how-to/create/)
2. Domain name (e.g. github.com)
  - You can buy one through [Namecheap](https://www.namecheap.com) 
3. DNS configuration to point the domain to the server
  - You can follow [these instructions](https://www.digitalocean.com/community/tutorials/how-to-point-to-digitalocean-nameservers-from-common-domain-registrars) to configure DNS for DigitalOcean

Verify that your domain points to your server's IP with:
```
nslookup {host}
```

### Setup
Set up your server with the following commands.

**1. Clone the repo**
```
git clone git@github.com:christianbator/webhost.git
cd webhost
```

**2. Add Webhost utilities to PATH**
In `.zshrc`:
```
export PATH="$HOME/path/to/webhost/bin:$PATH"
```

**3. Configure the server**
Create a user named `webhost` with `sudo` privileges:
```
webhost create_user {host}
```

- Everything from now on will be run from the `webhost` user. You're forced to create a new password - do so when prompted after running:
```
ssh webhost@{host}
```

Install [nginx](https://www.nginx.com/resources/wiki/) and
  [certbot](https://letsencrypt.org), and set up a firewall:
```
webhost install_deps {host}
```

**4. Encrypt the traffic**
```
webhost install_certs {host}
```

1) Enter the webhost password when prompted
2) For verification, select option 1: "Run an HTTP server locally"
3) Follow along with any other prompts

**5. Enabling website**
Update the nginx config either locally or remotely:
```
webhost update_nginx {host} (-l | --local) {port} (-p | --protected)
```

Note: for local config, always run the command from the directory above the `content/` directory.

If protected (with args (-p | --protected)), there is a `content/protected` dir to serve files.

### Notes
- Website
  - The website is served as static content from nginx out of the
    `/home/webhost/{host}` directory

- Routing
  - All HTTP traffic is redirected to HTTPS
  - All www urls are redirected to non www
  - All trailing slash urls are rewritten to non trailing slash urls

## Usage
There are a couple tools to help manage your site.

### Pushing Content
```
webhost push {host}
```

### Content
The website must have a `content/` directory, and the following structure is recommended:
```
content/
  sitemap.txt
  robots.txt
  icons/
  images/
  styles/
    fonts/
  thumbnails/
  videos/
  pages/
```

### Icons

Fill in the `content/icons` directory with the following files
so your site will automatically serve a favicon, social media post card image, and Apple touch icon:

```
favicon-0.png (64x64)
high-res-0.png (900x900)
apple-touch-icon-0.png (180x180)
```

If you ever need to update them, simply bump the number to 1, 2, 3, etc.
