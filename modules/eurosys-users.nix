{ config, lib, pkgs, ... }:
let
  joergsKey = ''
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7ymgN0OyRio14LNeyZg0I3frGXscYg/6Foab+BEE/uvY3iQj4//GZUd60Kp/mbBBWWoMq08Y7SV3wnkMWkhP5qtvTf44b7qNqo6lWyg8IooeqKl8TyNTwbAMxyBRDYl4Czu5IWpMdM8m1QD6G9NKAWWNf+36d4A5THfvUsYUMRpcOaTQchPbtrKdBE5z9No7jscBfmtF0VRxB/OvFImcF+PH2rWmKul99tLX9e6HunInoe1met1z18jThkeByWhSFypYL8JxXR8zLfDB1pT6/3XW062h7a/5qjUvREpMtHHlszuksZJkeU2BcHqQhbQ5BwPXTICjJuAYpeFDg+/Pqg4M0a0icDc+WmoPpsSU7Xx5O5CRvkH66R/lxYh95eF1wEU4K0/Z4m4V3X6BattV0zgu691it4ZidVEBdNtgdFu29pEExaKDcUF689MujE1PREpl/yOx+KiKD7iFJgWKhg2i47oz0s7BNbMwcU7nJJvoBLlePqLWkMsuF+MwwUEolTd21uqWsYzcqB9AkT9xBp11wgWB8+FAi9vWzg5O/A7FXdQ3eV7ZLgJH1MxR4DxtKErBCHzBzs6U+OpiXScp2AYD3OPgffCM2DtiJbcLMQqktNTsTsiw+EgOdwffufmenXcSU6d74KNlu12hsFU8LHyKb9edhHPvFEkdnCuZYyw== joerg@turingmachine
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKbBp2dH2X3dcU1zh+xW3ZsdYROKpJd3n13ssOP092qE joerg@turingmachine
  '';
  tester2Key = ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIfp3boCy9Pz8khCuh2oeyMxv/n2Ey+E2eAHbGjUWqTM tester1@everywhere
  '';
in {
  users.extraUsers = {
    tester1 = {
      isNormalUser = true;
      home = "/scratch/tester1";
      extraGroups = [ "wheel" "plugdev" "vboxusers" "adbusers" "input" ];
      shell = "/run/current-system/sw/bin/zsh";
      uid = 1007;
      openssh.authorizedKeys.keys = [ joergsKey tester2Key ];
    };
  };
}
