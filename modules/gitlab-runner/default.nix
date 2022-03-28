{
  pkgs,
  config,
  lib,
  ...
}: {
  sops.secrets.gitlab-runner-registration = {
    owner = "gitlab-runner";
    restartUnits = [
      "gitlab-runner"
    ];
    sopsFile = ./secrets.yml;
  };

  services.gitlab-runner = {
    enable = true;
    concurrent = 16;
    services.shell = {
      executor = "shell";
      registrationConfigFile = config.sops.secrets.gitlab-runner-registration.path;
    };
    extraPackages = with pkgs; [
      # Required stuff
      bash
      nettools # hostname
      git
      gnutar
      gzip
      rsync
      nix-eval-jobs
      config.nix.package
    ];
  };

  systemd.services.gitlab-runner = {
    confinement.enable = true;
    confinement.packages = config.services.gitlab-runner.extraPackages;
    serviceConfig = {
      User = "gitlab-runner";
      Group = "gitlab-runner";
      DynamicUser = lib.mkForce false;
      Environment = [
        "NIX_REMOTE=daemon"
        "PAGER=cat"
      ];
      BindPaths = [
        "/nix/var/nix/daemon-socket/socket"
        "/run/nscd/socket"
        "/var/lib/gitlab-runner"
      ];
      BindReadOnlyPaths = [
        # not sure if those are necessary
        "/etc/resolv.conf"
        "/etc/nsswitch.conf"

        "/etc/passwd"
        "/etc/group"
        "/nix/var/nix/profiles/system/etc/nix:/etc/nix"
        config.sops.secrets.gitlab-runner-registration.path
        "${config.environment.etc."ssl/certs/ca-certificates.crt".source}:/etc/ssl/certs/ca-certificates.crt"
        "${config.environment.etc."ssl/certs/ca-bundle.crt".source}:/etc/ssl/certs/ca-bundle.crt"
        "${config.environment.etc."ssh/ssh_known_hosts".source}:/etc/ssh/ssh_known_hosts"
        "${builtins.toFile "ssh_config" ''
          Host eve.thalheim.io
            ForwardAgent yes
        ''}:/etc/ssh/ssh_config"
        "/etc/machine-id"
        # channels are dynamic paths in the nix store, therefore we need to bind mount the whole thing
        "/nix/"
      ];
    };
  };

  users.users.gitlab-runner = {
    group = "gitlab-runner";
    isSystemUser = true;
    home = "/var/lib/gitlab-runner";
  };

  users.groups.gitlab-runner = {};

  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "yasmin.dse.in.tum.de";
      maxJobs = 96;
      sshKey = config.sops.secrets.gitlab-builder-ssh-key.path;
      sshUser = "ssh-ng://gitlab-builder";
      system = "aarch64-linux";
      supportedFeatures = [
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
    }
  ];

  sops.secrets.gitlab-builder-ssh-key.sopsFile = ./secrets.yml;
}
