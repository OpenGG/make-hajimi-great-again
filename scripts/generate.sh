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
