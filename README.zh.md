# 重振哈基米：整合你的留学和家庭网络

你是一位回国探亲的留学生吗？你是否发现自己一直在不停地切换不同的VPN应用？

你并不孤单。那种试图用一个应用连接大学资源，却又不得不切换到另一个应用来管理家庭NAS的挣扎，是一个非常令人头痛的问题。

对于安卓用户来说，这种情况尤其令人沮丧，因为他们经常面临一个限制：你不能同时运行Tailscale和原版哈基米。

这两个应用都依赖于系统的VPN隧道，而安卓系统一次只允许一个VPN连接处于活动状态。这意味着你必须不断地断开“留学”代理，才能启用Tailscale连接到你的家庭网络，反之亦然。这是一个繁琐的手动过程，让原本应该无缝衔接的体验变成了一种持续不断的麻烦。

但如果你不必做出选择呢？如果你能让你的“留学”网络和“家庭”网络同时运行，而且全部在一个应用里实现，那该多好？

本指南将向你展示如何通过哈基米 Meta的统一设置来做到这一点。是时候重振哈基米，享受一个真正一体化的网络体验了。

> 这就是哈基米 Meta，我们今天的英雄。快去对它说声“谢谢你，哈基米”。
> 

## 解决方案概览

我们的目标很简单：让哈基米 Meta足够智能，能够自动处理你的网络流量。

 * 当你访问你的家庭网络（例如，192.168.1.x）时，流量会通过加密隧道回传到你的家庭服务器。
 * 当你访问你的大学网站或其他学术资源时，流量会通过你的留学代理路由。
 * 所有其他国内流量则直接连接。

你只需四个步骤就能实现这个目标。

## 第1步：在你的家庭服务器上设置一个“虫洞”

你需要在你的家庭服务器（比如NAS、装有OpenWrt的路由器或任何Linux主机）上创建一个哈基米 Meta的入站隧道，我们称之为“虫洞”。这本质上是一个加密的SS入站监听器。

在你的服务器的`config.yaml`文件中，将以下内容添加到listeners部分：
```yaml
# ... your other configs, like outbound proxies, rules, etc. ...
# ... 你的其他配置，比如出站代理、规则等。 ...

listeners:
  # Other listeners...
  # 其他监听器...
  # This is the "wormhole" for going home
  # 这是“回老家”的“虫洞”
  - name: ss-inbound-for-home
    type: shadowsocks
    port: 23456 # Choose an unused port
    # 选择一个未被使用的端口
    listen: 0.0.0.0
    password: "your-server-password-random" # !!! CHANGE THIS to a STRONG, random password !!!
    # !!! 务必将其修改为一个强壮的随机密码 !!!
    cipher: aes-256-gcm # Recommended encryption method
    # 推荐的加密方法

# ... your other configs ...
# ... 你的其他配置 ...
```

关键点：
 * 将password更改为唯一且强度高的密码。
 * 端口23456只是一个例子；你可以使用不同的端口。
 * 切记在你的路由器和服务器防火墙中打开这个TCP和UDP端口。

💡 重要测试： 完成此步骤后，创建一个简单的home-client.yaml文件，只包含指向你服务器的SS代理配置。在一台客户端设备（比如电脑或另一部装有哈基米 Meta的手机）上使用它，在你的家庭网络内部测试是否能成功连接并访问家庭网络服务。这可以验证你的服务器设置是否正确。
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
    # 家庭服务器IP，例如 192.168.1.100，或者一个域名，例如 ip4p.your.domain.xyz
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
  # 将所有 192.168.1.0/24 网段的出站请求通过 home-proxy-group 代理
  - IP-CIDR,192.168.1.0/24,home-proxy-group

# uncomment all the following configs if you want to use ip4p domain names
# 如果你想使用 ip4p 域名，请取消注释以下所有配置
# ipv6: true
# dns:
#  ipv6: true
# experimental:
#  dialer-ip4p-convert: true
```

## 第2步：将“虫洞”暴露到互联网

为了从你的家庭网络外部访问你的“虫洞”，你需要一个公共地址。根据你的网络设置，选择以下三种方案之一。

### 方案A：公网IPv4地址（最可靠）

 * DDNS： 在你的路由器或NAS上使用DDNS（动态域名解析）服务来获取一个域名（例如home.yourdomain.com）。
 * 端口转发： 在你的路由器上设置一条规则，将来自公网端口23456的流量转发到你服务器的本地IP（例如192.168.1.100）的23456端口。

### 方案B：公网IPv6地址（很常见）

 * DDNS： 使用支持IPv6（AAAA记录）的DDNS服务，例如Cloudflare或https://v6.rocks。
 * 防火墙规则： 在你的路由器的IPv6防火墙中，允许外部访问你服务器的IPv6地址的23456端口。

这是一个简单的“允许”规则，而不是端口转发。

### 方案C：没有公网IP（高级）

如果你处于NAT（网络地址转换）后面，可以使用像natmap这样的工具进行NAT穿透。

 * 打洞与转发： natmap在打洞方面非常出色，但其内置的转发功能有时会失败。一个好的策略是，用natmap为23456端口打洞，然后手动在路由器的防火墙中配置一条转发规则。
 * DDNS： 你仍然需要一个域名，指向natmap暴露出的公共地址和端口。

详细说明可参考：https://github.com/heiher/natmap/wiki/ssh#openwrt-2203-or-later

💡 重要测试： 完成公网设置后，使用你的home-client.yaml文件，从非家庭网络（比如你手机的4G/5G）再次进行测试。如果你能成功连接并访问你的家庭网络服务，恭喜你——你的公网连接已正确配置。

## 第3步：创建主配置文件

现在，我们将你的“回老家”配置与你的“留学”配置（我们称之为crush.yaml）合并成一个功能强大的文件，命名为hajimi-great-again.yaml。
首先，创建一个名为home-client.yaml的文件，内容如下：
```yaml
proxies:
  # "Go Home" proxy node
  # “回老家”代理节点
  - name: "🏠 Return Home"
    type: ss
    server: your-ddns-domain.com # !!! CHANGE THIS to your domain from Step 2 !!!
    # !!! 务必将其更改为你在第2步中设置的域名 !!!
    port: 23456 # Must match the server side
    # 必须与服务器端匹配
    cipher: aes-256-gcm # Must match the server side
    # 必须与服务器端匹配
    password: "your-server-password-random" # !!! CHANGE THIS to match the server password !!!
    # !!! 务必将其更改为与服务器密码匹配 !!!
    udp: true

proxy-groups:
  # "Go Home" dedicated group
  # “回老家”专用组
  - name: "Home Network"
    type: select
    proxies:
      - "🏠 Return Home"
      - "DIRECT" # Add a direct connection option, just in case
      # 添加一个直连选项，以防万一

rules:
  # CRITICAL RULE: Route all traffic for your home network range to the "Home Network" group
  # 关键规则：将所有针对家庭网络范围的流量路由到“Home Network”组
  - IP-CIDR,192.168.1.0/24,Home Network # !!! NOTE: Change this if your network isn't 192.168.1.x !!!
  # !!! 注意：如果你的网络不是 192.168.1.x，请修改此项 !!!
  # You can also add other home network rules
  # 你也可以添加其他家庭网络规则
  # - DOMAIN-SUFFIX,internal.domain,Home Network
```

接下来，使用yq工具将其与你的crush.yaml合并：

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

这个命令会添加新的代理和代理组，并且至关重要的是，它将“回老家”的规则放在了列表的最前面，确保它们拥有最高的优先级。

## 第4步：在你的手机上完成设置

最后一步是在你的手机上配置哈基米 Meta客户端。

 * 将`hajimi-great-again.yaml`文件导入到应用中。
 * 切换到这个新配置。
 * !!! 这是最重要的一步 !!!
   进入设置 -> 网络 -> VPN服务，找到“绕过局域网”选项，并将其关闭！
   > 这个选项默认是开启的，它告诉系统自行处理局域网流量，这会彻底破坏“回老家”功能。我花了两个小时才搞明白这个设置！😡😡😡
   > 
 * 启动哈基米。

现在，尽情享受真正一体化的网络体验吧。

你现在可以同时访问你家的路由器管理页面192.168.1.1和你大学的网站，而且这一切都只在一个应用中完成。你的哈基米现在是一个完整的、集成的系统了。
