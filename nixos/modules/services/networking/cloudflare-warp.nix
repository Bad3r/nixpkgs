{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cloudflare-warp;

  systemdLogLevels = [
    "emerg"
    "alert"
    "crit"
    "err"
    "warning"
    "notice"
    "info"
    "debug"
  ];
in
{
  options.services.cloudflare-warp = {
    enable = lib.mkEnableOption "Cloudflare Zero Trust client daemon";

    package = lib.mkPackageOption pkgs "cloudflare-warp" { };

    rootDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/cloudflare-warp";
      description = ''
        Working directory for the warp-svc daemon.
      '';
    };

    # Cloudflare WARP 2025.7.176.0 made MASQUE the default tunnel protocol for
    # new Linux device profiles. Keep WireGuard's UDP 2408 ingress port in the
    # default list so existing profiles continue to work.
    udpPort = lib.mkOption {
      type = lib.types.coercedTo lib.types.port lib.singleton (lib.types.listOf lib.types.port);
      default = [
        443
        2408
      ];
      example = [
        443
        2408
        500
        1701
        4500
        4443
        8443
        8095
      ];
      description = ''
        UDP ports to open in the firewall for Cloudflare WARP ingress. MASQUE uses UDP 443 by default
        and WireGuard uses UDP 2408. Fallback ports can be added when needed. See the
        [firewall documentation](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/firewall/)
        for the available fallback ports.
      '';
    };

    logLevelMax = lib.mkOption {
      type = lib.types.enum systemdLogLevels;
      default = "warning";
      description = ''
        Maximum log level emitted by the cloudflare-warp systemd service.
      '';
    };

    openFirewall = lib.mkEnableOption "opening UDP ports in the firewall" // {
      default = true;
    };

    taskbar.enable = lib.mkEnableOption "Cloudflare WARP taskbar service" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = cfg.udpPort;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.rootDir}    - root root"
      "z ${cfg.rootDir}    - root root"
    ];

    systemd.services.cloudflare-warp = {
      enable = true;
      description = "Cloudflare Zero Trust Client Daemon";

      # lsof is used by the service to determine which UDP port to bind to
      # in the case that it detects collisions.
      path = [ pkgs.lsof ];
      requires = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig =
        let
          caps = [
            "CAP_NET_ADMIN"
            "CAP_NET_BIND_SERVICE"
            "CAP_SYS_PTRACE"
          ];
        in
        {
          Type = "simple";
          ExecStart = "${cfg.package}/bin/warp-svc";
          LogLevelMax = cfg.logLevelMax;
          ReadWritePaths = [
            "${cfg.rootDir}"
            "/etc/resolv.conf"
          ];
          CapabilityBoundingSet = caps;
          AmbientCapabilities = caps;
          Restart = "always";
          RestartSec = 5;
          Environment = [ "RUST_BACKTRACE=full" ];
          WorkingDirectory = cfg.rootDir;

          # See the systemd.exec docs for the canonicalized paths, the service
          # makes use of them for logging, and account state info tracking.
          # https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#RuntimeDirectory=
          StateDirectory = "cloudflare-warp";
          RuntimeDirectory = "cloudflare-warp";
          LogsDirectory = "cloudflare-warp";

          # The service needs to write to /etc/resolv.conf to configure DNS, so that file would have to
          # be world read/writable to run as anything other than root.
          User = "root";
          Group = "root";
        };

    };

    systemd.user.services.warp-taskbar = {
      enable = cfg.taskbar.enable;
      description = "Cloudflare Zero Trust Client Taskbar";
      requires = [ "dbus.socket" ];
      after = [
        "dbus.socket"
        "graphical-session.target"
      ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];

      serviceConfig = {
        Type = "dbus";
        BusName = "com.cloudflare.WarpTaskbar";
        ExecStart = "${cfg.package}/bin/warp-taskbar";
        Restart = "always";
        RestartSec = 5;
        BindReadOnlyPaths = [ "${cfg.package}:/usr:" ];
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ treyfortmuller ];
}
