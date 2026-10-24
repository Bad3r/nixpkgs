{ pkgs, ... }:
{
  name = "libvirtd";
  meta.maintainers = with pkgs.lib.maintainers; [ fpletz ];

  nodes = {
    virthost =
      { lib, pkgs, ... }:
      {
        virtualisation = {
          cores = 2;
          memorySize = 2048;

          libvirtd.enable = true;
          libvirtd.hooks.qemu.is_working = "${pkgs.writeShellScript "testHook.sh" ''
            touch /tmp/qemu_hook_is_working
          ''}";
          libvirtd.nss.enable = true;
          libvirtd.dbus.enable = true;
          libvirtd.qemu.firmwarePackages = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
            ovmf-full = pkgs.OVMFFull.fd;
          };
        };
        boot.supportedFilesystems = [ "zfs" ];
        networking.hostId = "deadbeef"; # needed for zfs
        security.polkit.enable = true;
        environment.systemPackages = with pkgs; [ virt-manager ];

        # This adds `resolve` to the `hosts` line of /etc/nsswitch.conf; NSS modules placed after it
        # will not be consulted. Therefore this tests that the libvirtd NSS modules will be
        # be placed early enough for name resolution to work.
        services.resolved.enable = true;
      };
  };

  testScript =
    let
      nixosInstallISO = (import ../release.nix { }).iso_minimal.${pkgs.stdenv.hostPlatform.system};
      virshShutdownCmd = if pkgs.stdenv.hostPlatform.isx86_64 then "shutdown" else "destroy";
      efiDomain =
        name: firmware:
        pkgs.writeText "${name}.xml" ''
          <domain type="qemu">
            <name>${name}</name>
            <memory unit="MiB">256</memory>
            <os firmware="efi">
              <type arch="x86_64" machine="q35">hvm</type>
              ${firmware}
            </os>
            <features>
              <acpi/>
              <smm state="on"/>
            </features>
          </domain>
        '';
      plainEfiDomain = efiDomain "plain-efi" "";
      secureBootEfiDomain = efiDomain "secure-boot-efi" ''
        <firmware>
          <feature enabled="yes" name="secure-boot"/>
        </firmware>
      '';
      enrolledEfiDomain = efiDomain "enrolled-efi" ''
        <firmware>
          <feature enabled="yes" name="secure-boot"/>
          <feature enabled="yes" name="enrolled-keys"/>
        </firmware>
      '';
    in
    ''
      start_all()

      virthost.wait_for_unit("multi-user.target")

      with subtest("enable default network"):
        virthost.succeed("virsh net-start default")
        virthost.succeed("virsh net-autostart default")
        virthost.succeed("virsh net-info default")

      with subtest("check if partition disk pools works with parted"):
        virthost.succeed("fallocate -l100m /tmp/foo; losetup /dev/loop0 /tmp/foo; echo 'label: dos' | sfdisk /dev/loop0")
        virthost.succeed("virsh pool-create-as foo disk --source-dev /dev/loop0 --target /dev")
        virthost.succeed("virsh vol-create-as foo loop0p1 25MB")
        virthost.succeed("virsh vol-create-as foo loop0p2 50MB")

      with subtest("check if virsh zfs pools work"):
        virthost.succeed("fallocate -l100m /tmp/zfs; losetup /dev/loop1 /tmp/zfs;")
        virthost.succeed("zpool create zfs_loop /dev/loop1")
        virthost.succeed("virsh pool-define-as --name zfs_storagepool --source-name zfs_loop --type zfs")
        virthost.succeed("virsh pool-start zfs_storagepool")
        virthost.succeed("virsh vol-create-as zfs_storagepool disk1 25MB")

      with subtest("check if nixos install iso boots, network and autostart works"):
        # The guest runs sshd on port 22. We use passt-based networking to
        # forward guest port 22 to host port 2222 and `nc -z` to assert that
        # the host port can only be connected to once the guest is running.
        virthost.fail("nc -z localhost 2222")
        virthost.succeed(
          "virt-install -n nixos --osinfo nixos-unstable --memory 1024 --graphics none --network default --network passt,portForward=2222:22 --disk `find ${nixosInstallISO}/iso -type f | head -n1`,readonly=on --import --noautoconsole --autostart"
        )
        virthost.succeed("virsh domstate nixos | grep running")
        virthost.wait_until_succeeds("ping -c 1 nixos")
        virthost.succeed("nc -z localhost 2222")
        virthost.succeed("virsh ${virshShutdownCmd} nixos")
        virthost.wait_until_succeeds("virsh domstate nixos | grep 'shut off'")
        virthost.shutdown()
        virthost.wait_for_unit("multi-user.target")
        virthost.wait_until_succeeds("ping -c 1 nixos")
        virthost.succeed("nc -z localhost 2222")

      with subtest("test if hooks are linked and run"):
        virthost.succeed("ls /var/lib/libvirt/hooks/qemu.d/is_working")
        virthost.succeed("ls /tmp/qemu_hook_is_working")

      with subtest("check libvirt over dbus"):
        # The service is activated on-demand and shouldn't be active yet
        virthost.fail("systemctl is-active libvirt-dbus.service")

        # Get the hostname property of the Test connection (this will activate the service)
        virthost.succeed("busctl get-property org.libvirt /org/libvirt/Test org.libvirt.Connect Hostname")

        # Now the service should be active
        virthost.succeed("systemctl is-active libvirt-dbus.service")
    ''
    + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isx86_64 ''

      with subtest("check firmware selection with firmwarePackages"):
        import xml.etree.ElementTree as ET

        def define_and_get_firmware(name, xml):
          virthost.succeed(f"virsh define {xml}")
          os_ = ET.fromstring(virthost.succeed(f"virsh dumpxml {name}")).find("os")
          assert os_ is not None
          return os_.findtext("loader", ""), os_.find("nvram")

        def start_and_destroy(name):
          virthost.succeed(f"virsh start {name}")
          virthost.succeed(f"virsh domstate {name} | grep running")
          virthost.succeed(f"virsh destroy {name}")

        # tmpfiles owns the link, so a switch restores it even if it was
        # replaced by a directory.
        virthost.succeed("rm /run/libvirt/nix-ovmf/ovmf-full && mkdir /run/libvirt/nix-ovmf/ovmf-full")
        virthost.succeed("systemctl restart systemd-tmpfiles-resetup.service libvirtd-config.service")
        link = virthost.succeed("readlink /run/libvirt/nix-ovmf/ovmf-full").strip()
        assert link == "${pkgs.OVMFFull.fd}", link

        # Only the OVMFFull descriptors provide enrolled-keys.
        loader, nvram = define_and_get_firmware("enrolled-efi", "${enrolledEfiDomain}")
        assert loader.startswith("/run/libvirt/nix-ovmf/ovmf-full/"), loader
        assert nvram is not None
        template = nvram.get("template", "")
        assert template.startswith("/run/libvirt/nix-ovmf/ovmf-full/"), template
        assert template.endswith("/OVMF_VARS.ms.fd"), template
        start_and_destroy("enrolled-efi")

        # The firmware bundled with QEMU already provides secure-boot.
        loader, _ = define_and_get_firmware("secure-boot-efi", "${secureBootEfiDomain}")
        assert loader.startswith("/run/libvirt/nix-ovmf/"), loader
        assert not loader.startswith("/run/libvirt/nix-ovmf/ovmf-full/"), loader
        start_and_destroy("secure-boot-efi")

        # Plain EFI domains keep getting the firmware bundled with QEMU
        # instead of firmware with Microsoft keys enrolled.
        loader, _ = define_and_get_firmware("plain-efi", "${plainEfiDomain}")
        assert loader.startswith("/run/libvirt/nix-ovmf/"), loader
        assert not loader.startswith("/run/libvirt/nix-ovmf/ovmf-full/"), loader
        start_and_destroy("plain-efi")
    '';
}
