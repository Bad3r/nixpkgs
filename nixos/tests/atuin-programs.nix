{ pkgs, ... }:
{
  name = "atuin";
  meta.maintainers = pkgs.atuin.meta.maintainers;

  nodes.machine = {
    programs = {
      bash.enable = true;
      fish.enable = true;
      zsh.enable = true;

      atuin = {
        enable = true;
        settings = {
          auto_sync = false;
        };
      };
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("default.target")

    # Check atuin is installed
    machine.succeed("atuin --version")

    # Check non-interactive search
    machine.succeed(
      "ATUIN_SESSION=$(atuin uuid); export ATUIN_SESSION; "
      "atuin history start 'atuin-search-test' && "
      "atuin search --cmd-only atuin-search-test | grep -Fx atuin-search-test"
    )

    # Check shell integration. Bash needs a pseudo-terminal for readline bindings.
    machine.succeed("script --quiet --return /dev/null -- bash -ic 'eval \"$(atuin init bash)\"'")
    machine.succeed("zsh -c 'eval \"$(atuin init zsh)\"'")
    machine.succeed("fish -c 'atuin init fish | source'")

    # Verify config file was created
    machine.succeed("grep -q 'auto_sync = false' /etc/atuin/config.toml")

    # Verify daemon socket unit is enabled
    machine.succeed("systemctl --global is-enabled atuin-daemon.socket")
  '';
}
