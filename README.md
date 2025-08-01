# Make Hajimi Great Again: Unifying Your Study Abroad and Home Networks

Are you an international student who has returned home, only to find yourself constantly switching between VPN apps? 

You're not alone. The struggle of trying to connect to your university’s resources with one app and then managing your home NAS with another is a major pain point.

This is especially true for Android users, who often face a frustrating limitation: you can't run Tailscale and the original Hajimi at the same time.

These apps both rely on the system's VPN tunnel, and Android only allows one active VPN connection at a time. This means you have to constantly disconnect from your "go abroad" proxy to enable Tailscale for your home network, and vice versa. It’s a tedious, manual process that makes what should be a seamless experience into a constant hassle.

But what if you didn’t have to choose? What if you could have both your "study abroad" network and your "home" network running simultaneously, all within a single app?

This guide will show you how to do exactly that, all thanks to a unified setup with Hajimi Meta. It's time to make Hajimi great again and enjoy a truly integrated network experience.

![Hajimi Meta](https://wiki.metacubex.one/assets/images.jpeg)

> This is Hajimi Meta, our hero for today. Go ahead and say, "Thank you, Hajimi."

## Solution Overview

Our goal is simple: make Hajimi Meta smart enough to handle your network traffic automatically.

 * When you visit your home network (e.g., 192.168.1.x), the traffic goes through an encrypted tunnel back to your home server.
 * When you access your university website or other academic resources, the traffic is routed through your study abroad proxy.
 * All other domestic traffic connects directly.

You can achieve this in just four steps.

## Step 1: Set Up a "Wormhole" on Your Home Server

You'll need to create a Hajimi Meta inbound tunnel on your home server (like a NAS, router with OpenWrt, or any Linux host) that we'll call a "wormhole." This is essentially an encrypted ss inbound listener.

In your server's `config.yaml` file, add the following to the listeners section:

```yaml
# ... your other configs, like outbound proxies, rules, etc. ...

listeners:
  # Other listeners...
  # This is the "wormhole" for going home
  - name: ss-inbound-for-home
    type: shadowsocks
    port: 23456 # Choose an unused port
    listen: 0.0.0.0
    password: "your-server-password-random" # !!! CHANGE THIS to a STRONG, random password !!!
    cipher: aes-256-gcm # Recommended encryption method

# ... your other configs ...
```

Key Points:
 * Change the password to a unique, strong password.
 * The port 23456 is an example; you can use a different one.
 * Remember to open this TCP and UDP port in your router and server firewall.

💡 Important Test: After this step, create a simple `home-client.yaml` file with just the ss proxy configuration pointing to your server. Use it on a client device (like a computer or another phone with Hajimi Meta) to confirm that you can successfully connect and access your home network services from within your home network. This verifies your server setup is correct.

```yaml
port: 7890
mixed-port: 7891
mode: rule
log-level: info
allow-lan: false
bind-address: '*'
unified-delay: true
external-controller: '0.0.0.0:9090'
secret: 'your-client-password-random'

proxies:
  - name: "home-ss-proxy"
    type: ss
    # home server ip such as 192.168.1.100，or a domain name like ip4p.your.domain.xyz
    server: home-server-ip
    port: 23456
    cipher: aes-256-gcm
    password: "your-server-password-random"
    udp: true

proxy-groups:
  - name: "home-proxy-group"
    type: select
    proxies:
      - "home-ss-proxy"
      - "DIRECT"

rules:
  # proxy all 192.168.1.0/24 outgoing requests through home-proxy-group
  - IP-CIDR,192.168.1.0/24,home-proxy-group

# uncomment all the following configs if you want to use ip4p domain names
# ipv6: true
# dns:
#  ipv6: true
# experimental:
#  dialer-ip4p-convert: true
```


## Step 2: Expose the "Wormhole" to the Internet

To access your "wormhole" from outside your home, you need a public address. Pick one of these three options based on your network setup.

### Option A: Public IPv4 Address (Most Reliable)

 * DDNS: Use DDNS on your router or NAS to get a domain name (e.g., home.yourdomain.com).
 * Port Forwarding: Set up a rule on your router to forward traffic from public port 23456 to your server's local IP (e.g., 192.168.1.100) on port 23456.

### Option B: Public IPv6 Address (Very Common)

 * DDNS: Use a DDNS service that supports IPv6 (AAAA records), like Cloudflare or https://v6.rocks .
 * Firewall Rule: In your router's IPv6 firewall, allow external access to your server's IPv6 address on port 23456.

This is a simple "allow" rule, not port forwarding.

### Option C: No Public IP (Advanced)

If you are behind a NAT, you can use tools like natmap for NAT traversal.

 * Hole Punching & Forwarding: natmap is great for hole punching but sometimes its built-in forwarding fails. A good strategy is to use natmap to punch a hole for port 23456 and then manually configure a forwarding rule in your router's firewall.
 * DDNS: You'll still need a domain name that points to the public address and port exposed by natmap.

A detailed instruction: https://github.com/heiher/natmap/wiki/ssh#openwrt-2203-or-later

💡 Important Test: Once you've completed your public network setup, use your home-client.yaml file to test again from a non-home network (e.g., your phone's 4G/5G). If you can successfully connect and access your home network services, congratulations—your public connection is configured correctly.

## Step 3: Create the Master Config File

Now, we'll merge your "go home" configuration with your "study abroad" configuration (let's call it `crush.yaml`) into one powerful file named `hajimi-great-again.yaml`.

First, create a file called `home-client.yaml` with the following content:

```yaml
proxies:
  # "Go Home" proxy node
  - name: home-ss-proxy
    type: ss
    server: your-ddns-domain.com # !!! CHANGE THIS to your domain from Step 2 !!!
    port: 23456 # Must match the server side
    cipher: aes-256-gcm # Must match the server side
    password: "your-server-password-random" # !!! CHANGE THIS to match the server password !!!
    udp: true

proxy-groups:
  # "Go Home" dedicated group
  - name: home-proxy-group
    type: select
    proxies:
      - home-ss-proxy
      - DIRECT # Add a direct connection option, just in case

rules:
  # CRITICAL RULE: Route all traffic for your home network range to the "Home Network" group
  - IP-CIDR,192.168.1.0/24,home-proxy-group # !!! NOTE: Change this if your network isn't 192.168.1.x !!!
  # You can also add other home network rules
  # - DOMAIN-SUFFIX,internal.domain,home-proxy-group
```

Next, use the yq tool to merge this with your `crush.yaml`:

```bash
yq e '
(
  .proxies += load("home-client.yaml").proxies |
  ."proxy-groups" += load("home-client.yaml")."proxy-groups" |
  .rules = load("home-client.yaml").rules + .rules |
  .ipv6 = load("home-client.yaml").ipv6 |
  .dns = (.dns // {}) * load("home-client.yaml").dns |
  .experimental = (.experimental // {}) * load("home-client.yaml").experimental
)
' crush.yaml > hajimi-great-again.yaml
```

This command appends the new proxy and group, and critically, it places the "go home" rules at the beginning of the list, ensuring they have the highest priority.

## Step 4: Finalize the Setup on Your Phone

The last step is to configure the Hajimei Meta client on your phone.

 * Import the `hajimei-great-again.yaml` file into the app.
 * Switch to this new configuration.
 * !!! THIS IS THE MOST IMPORTANT STEP !!!
   Go to Settings -> Network -> VPN Services, find "Bypass private networks," and turn it OFF!
   > This option is on by default and tells the system to handle private network traffic on its own, completely breaking the "go home" function. This one setting took me two hours to figure out! 😡😡😡
   > 
 * Start Hajimei.


Now, enjoy a truly unified network experience.

You can access your home router's admin page at 192.168.1.1 and your university's website at the same time, all from a single app. Your Hajimi is now a complete, integrated system.
