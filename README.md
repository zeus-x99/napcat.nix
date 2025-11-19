# napcat.nix

Fork from [chronocat.nix](https://github.com/Anillc/chronocat.nix)

NixOS module for running NapCat QQ bot service. NapCat is a modern protocol-side framework based on NTQQ.

# 使用方法

## 在 NixOS 中使用（推荐）

### 1. 添加到 flake inputs

在你的 `flake.nix` 中添加 napcat 到 inputs：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    napcat = {
      url = "github:zeus-x99/napcat.nix";  # 或使用你的仓库地址
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, napcat, ... }@inputs: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        napcat.nixosModules.default  # 导入 NapCat 模块
      ];
    };
  };
}
```

### 2. 配置 NapCat 实例

创建配置文件（例如 `napcat-instances.nix`）：

```nix
{ ... }:
{
  services.napcat.instances = {
    "123456789" = {  # 你的 QQ 号
      enable = true;

      # HTTP 服务器配置
      httpServers = [{
        name = "default";
        enable = true;
        port = 3000;
        host = "0.0.0.0";
        token = "your-token-here";  # 建议设置鉴权密钥
      }];

      # 或使用 WebSocket 服务器
      websocketServers = [{
        name = "default";
        enable = true;
        port = 3001;
        host = "0.0.0.0";
        token = "your-token-here";
      }];
    };
  };
}
```

### 3. 应用配置

```bash
sudo nixos-rebuild switch --flake .#your-hostname
```

### 4. 管理服务

```bash
# 查看服务状态
sudo systemctl status napcat-123456789

# 查看日志
sudo journalctl -u napcat-123456789 -f

# 重启服务
sudo systemctl restart napcat-123456789
```

### 配置文件位置

- QQ 配置目录：`/var/lib/napcat/QQ号/qq`
- NapCat 配置：`/var/lib/napcat/QQ号/napcat/config/onebot11_QQ号.json`

服务启动后，首次运行会生成默认配置文件，你可以手动编辑配置文件后重启服务。

## 快速体验

```shell
nix run github:zeus-x99/napcat.nix
```

## setup nix

[NixOS](https://nixos.org/download/)

```shell
sh <(curl -L https://nixos.org/nix/install) --daemon
```

```shell
mkdir -p ~/.config/nix && touch ~/.config/nix/nix.conf
vi ~/.config/nix/nix.conf
# 写入
experimental-features = nix-command flakes
```

```shell
nix flake update
nix build
nix run
```

## 配置选项

### HTTP 服务器

```nix
httpServers = [{
  name = "default";
  enable = true;
  port = 3000;
  host = "0.0.0.0";
  enableCors = true;
  enableWebsocket = true;
  messagePostFormat = "array";  # 或 "string"
  token = "";  # 建议设置
  debug = false;
}];
```

### WebSocket 服务器（正向 WS）

```nix
websocketServers = [{
  name = "default";
  enable = true;
  port = 3001;
  host = "0.0.0.0";
  messagePostFormat = "array";
  reportSelfMessage = false;
  token = "";
  enableForcePushEvent = true;
  debug = false;
  heartInterval = 30000;
}];
```

### HTTP 客户端（上报）

```nix
httpClients = [{
  name = "default";
  enable = true;
  url = "http://your-server:port/webhook";
  messagePostFormat = "array";
  reportSelfMessage = false;
  token = "";
  debug = false;
}];
```

### WebSocket 客户端（反向 WS）

```nix
websocketClients = [{
  name = "default";
  enable = true;
  url = "ws://your-server:port/ws";
  messagePostFormat = "array";
  reportSelfMessage = false;
  token = "";
  reconnectInterval = 5000;
  debug = false;
  heartInterval = 30000;
}];
```

## License

MIT

