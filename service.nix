{ pkgs, lib, config, ... }:
let
  cfg = config.services.napcat;
  napcatSrc = ./src;

  # OneBot 配置类型定义
  httpServerType = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; description = "HTTP 服务器唯一标识"; };
      enable = lib.mkOption { type = lib.types.bool; default = false; description = "是否启用此 HTTP 服务器"; };
      port = lib.mkOption { type = lib.types.port; default = 3000; description = "监听端口"; };
      host = lib.mkOption { type = lib.types.str; default = "0.0.0.0"; description = "监听主机地址"; };
      enableCors = lib.mkOption { type = lib.types.bool; default = true; description = "是否启用 CORS"; };
      enableWebsocket = lib.mkOption { type = lib.types.bool; default = true; description = "是否启用 WebSocket"; };
      messagePostFormat = lib.mkOption { type = lib.types.enum ["array" "string"]; default = "array"; description = "消息上报格式"; };
      token = lib.mkOption { type = lib.types.str; default = ""; description = "鉴权密钥（建议设置）"; };
      debug = lib.mkOption { type = lib.types.bool; default = false; description = "是否上报 raw 数据"; };
    };
  };

  httpClientType = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; description = "HTTP 客户端唯一标识"; };
      enable = lib.mkOption { type = lib.types.bool; default = false; description = "是否启用此 HTTP 客户端"; };
      url = lib.mkOption { type = lib.types.str; description = "消息上报地址"; };
      messagePostFormat = lib.mkOption { type = lib.types.enum ["array" "string"]; default = "array"; description = "消息上报格式"; };
      reportSelfMessage = lib.mkOption { type = lib.types.bool; default = false; description = "是否上报自身消息"; };
      token = lib.mkOption { type = lib.types.str; default = ""; description = "鉴权密钥（建议设置）"; };
      debug = lib.mkOption { type = lib.types.bool; default = false; description = "是否上报 raw 数据"; };
    };
  };

  websocketServerType = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; description = "WebSocket 服务器唯一标识"; };
      enable = lib.mkOption { type = lib.types.bool; default = false; description = "是否启用此 WebSocket 服务器（正向 WS）"; };
      host = lib.mkOption { type = lib.types.str; default = "0.0.0.0"; description = "监听主机地址"; };
      port = lib.mkOption { type = lib.types.port; default = 3001; description = "监听端口"; };
      messagePostFormat = lib.mkOption { type = lib.types.enum ["array" "string"]; default = "array"; description = "消息上报格式"; };
      reportSelfMessage = lib.mkOption { type = lib.types.bool; default = false; description = "是否上报自身消息"; };
      token = lib.mkOption { type = lib.types.str; default = ""; description = "鉴权密钥（建议设置）"; };
      enableForcePushEvent = lib.mkOption { type = lib.types.bool; default = true; description = "是否强制推送事件"; };
      debug = lib.mkOption { type = lib.types.bool; default = false; description = "是否上报 raw 数据"; };
      heartInterval = lib.mkOption { type = lib.types.int; default = 30000; description = "心跳间隔（毫秒）"; };
    };
  };

  websocketClientType = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; description = "WebSocket 客户端唯一标识"; };
      enable = lib.mkOption { type = lib.types.bool; default = false; description = "是否启用此 WebSocket 客户端（反向 WS）"; };
      url = lib.mkOption { type = lib.types.str; description = "消息上报地址（ws:// 或 wss://）"; };
      messagePostFormat = lib.mkOption { type = lib.types.enum ["array" "string"]; default = "array"; description = "消息上报格式"; };
      reportSelfMessage = lib.mkOption { type = lib.types.bool; default = false; description = "是否上报自身消息"; };
      reconnectInterval = lib.mkOption { type = lib.types.int; default = 5000; description = "重连间隔（毫秒）"; };
      token = lib.mkOption { type = lib.types.str; default = ""; description = "鉴权密钥（建议设置）"; };
      debug = lib.mkOption { type = lib.types.bool; default = false; description = "是否上报 raw 数据"; };
      heartInterval = lib.mkOption { type = lib.types.int; default = 30000; description = "心跳间隔（毫秒）"; };
    };
  };

  onebotConfigType = lib.types.submodule {
    options = {
      network = lib.mkOption {
        type = lib.types.submodule {
          options = {
            httpServers = lib.mkOption {
              type = lib.types.listOf httpServerType;
              default = [];
              description = "HTTP 服务器列表";
            };
            httpClients = lib.mkOption {
              type = lib.types.listOf httpClientType;
              default = [];
              description = "HTTP 客户端列表";
            };
            websocketServers = lib.mkOption {
              type = lib.types.listOf websocketServerType;
              default = [];
              description = "WebSocket 服务器列表（正向 WS）";
            };
            websocketClients = lib.mkOption {
              type = lib.types.listOf websocketClientType;
              default = [];
              description = "WebSocket 客户端列表（反向 WS）";
            };
          };
        };
        default = {};
        description = "网络配置";
      };
      musicSignUrl = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "音乐签名服务器地址（用于发送音乐卡片）";
      };
      enableLocalFile2Url = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "是否将本地文件转换为 URL";
      };
      parseMultMsg = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "是否解析合并转发消息";
      };
    };
  };

  napcatConfigType = lib.types.submodule {
    options = {
      fileLog = lib.mkOption { type = lib.types.bool; default = true; description = "是否启用文件日志"; };
      consoleLog = lib.mkOption { type = lib.types.bool; default = true; description = "是否启用控制台日志"; };
      fileLogLevel = lib.mkOption { type = lib.types.enum ["debug" "info" "error"]; default = "info"; description = "文件日志等级"; };
      consoleLogLevel = lib.mkOption { type = lib.types.enum ["debug" "info" "error"]; default = "info"; description = "控制台日志等级"; };
      packetServer = lib.mkOption { type = lib.types.str; default = ""; description = "PacketServer 地址（高级功能）"; };
    };
  };

  webuiConfigType = lib.types.submodule {
    options = {
      host = lib.mkOption { type = lib.types.str; default = "0.0.0.0"; description = "监听主机地址"; };
      port = lib.mkOption { type = lib.types.int; default = 0; description = "监听端口（设置为 0 禁用 WebUI）"; };
      token = lib.mkOption { type = lib.types.str; default = ""; description = "登录密钥（留空自动生成）"; };
      loginRate = lib.mkOption { type = lib.types.int; default = 3; description = "每分钟登录次数限制"; };
    };
  };

  # 默认配置
  defaultOnebotConfig = {
    network = {
      httpServers = [];
      httpClients = [];
      websocketServers = [{
        name = "WsServer";
        enable = true;
        host = "0.0.0.0";
        port = 3001;
        messagePostFormat = "array";
        reportSelfMessage = false;
        token = "";
        enableForcePushEvent = true;
        debug = false;
        heartInterval = 30000;
      }];
      websocketClients = [];
    };
    musicSignUrl = "";
    enableLocalFile2Url = false;
    parseMultMsg = false;
  };

  defaultNapcatConfig = {
    fileLog = true;
    consoleLog = true;
    fileLogLevel = "info";
    consoleLogLevel = "info";
    packetServer = "";
  };

  defaultWebuiConfig = {
    host = "0.0.0.0";
    port = 0;
    token = "";
    loginRate = 3;
  };

  # 为每个实例创建服务
  mkNapcatService = qqNumber: instanceCfg:
  let
    # 自动生成目录路径
    baseDir = "/var/lib/napcat/${qqNumber}";
    qqConfigDir = "${baseDir}/qq";
    napcatConfigDir = "${baseDir}/napcat";
    cacheDir = "${baseDir}/cache";

    napcatPackage = pkgs.callPackage napcatSrc {
      config = {
        qq_config_dir = qqConfigDir;
        nc_config_dir = napcatConfigDir;
        cache_dir = cacheDir;
      };
    };

    # 将配置转换为 JSON
    onebotJson = builtins.toJSON instanceCfg.onebot;
    napcatJson = builtins.toJSON instanceCfg.napcat;
    webuiJson = builtins.toJSON instanceCfg.webui;
  in {
    name = "napcat-${qqNumber}";
    value = {
      enable = true;
      description = "NapCat QQ Bot - ${qqNumber}";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = instanceCfg.user;
        Group = instanceCfg.group;
        ExecStart = "${napcatPackage.script}/bin/NapCat -q ${qqNumber}";
        Restart = "on-failure";
        RestartSec = "10s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        StateDirectory = "napcat/${qqNumber}";
        StateDirectoryMode = "0755";
      };

      preStart = ''
        mkdir -p ${qqConfigDir}
        mkdir -p ${napcatConfigDir}
        mkdir -p ${cacheDir}

        # 创建 OneBot11 配置文件：onebot11_QQ号.json（每次启动重新生成）
        echo '${onebotJson}' | ${pkgs.jq}/bin/jq '.' > "${napcatConfigDir}/onebot11_${qqNumber}.json"

        # 创建 NapCat 核心配置文件：napcat_QQ号.json（每次启动重新生成）
        echo '${napcatJson}' | ${pkgs.jq}/bin/jq '.' > "${napcatConfigDir}/napcat_${qqNumber}.json"

        # 创建 WebUI 配置文件：webui.json（每次启动重新生成）
        echo '${webuiJson}' | ${pkgs.jq}/bin/jq '.' > "${napcatConfigDir}/webui.json"
      '';
    };
  };
in
{
  options.services.napcat = {
    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          enable = lib.mkEnableOption "Enable this NapCat instance";

          user = lib.mkOption {
            type = lib.types.str;
            default = "napcat";
            description = "运行 NapCat 的用户";
          };

          group = lib.mkOption {
            type = lib.types.str;
            default = "napcat";
            description = "运行 NapCat 的用户组";
          };

          onebot = lib.mkOption {
            type = onebotConfigType;
            default = defaultOnebotConfig;
            description = ''
              OneBot11 配置。
              配置文件会保存为：/var/lib/napcat/QQ号/napcat/onebot11_QQ号.json
              每次启动时会重新生成，Nix 配置是唯一真相来源。
            '';
          };

          napcat = lib.mkOption {
            type = napcatConfigType;
            default = defaultNapcatConfig;
            description = ''
              NapCat 核心配置。
              配置文件会保存为：/var/lib/napcat/QQ号/napcat/napcat_QQ号.json
              每次启动时会重新生成。
            '';
          };

          webui = lib.mkOption {
            type = webuiConfigType;
            default = defaultWebuiConfig;
            description = ''
              WebUI 配置。
              配置文件会保存为：/var/lib/napcat/QQ号/napcat/webui.json
              每次启动时会重新生成。
              设置 port = 0 可以禁用 WebUI（默认禁用）。
            '';
          };
        };
      }));
      default = {};
      description = ''
        NapCat 实例配置。
        键名应该是 QQ 号，会自动创建目录：/var/lib/napcat/QQ号/
      '';
    };
  };

  config = lib.mkIf (cfg.instances != {}) {
    systemd.services = lib.mapAttrs' mkNapcatService
      (lib.filterAttrs (name: instanceCfg: instanceCfg.enable) cfg.instances);

    users.users.napcat = {
      isSystemUser = true;
      group = "napcat";
      description = "NapCat service user";
    };

    users.groups.napcat = {};
  };
}
