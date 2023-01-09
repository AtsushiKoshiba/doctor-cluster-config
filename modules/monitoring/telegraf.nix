{ config, lib, ... }:
let
  urls = [
    "nardole.r"
    "bill.r"
    "nardole.r"
    "yasmin.r"
    "graham.r"
    "ryan.r"

    "astrid.r"
    "dan.r"
    "mickey.r"

    "jackson.r"
    "christina.r"
    "adelaide.r"
    "wilfred.r"
    "river.r"
    "jack.r"
  ];
in
{
  services.telegraf.extraConfig.inputs = {
    ping =
      map
        (url: {
          method = "native";
          urls = [ "6.${url}" ];
          ipv6 = true;
          tags.org = "uni";
          tags.host = lib.removeSuffix ".r" url;
        })
        urls;
    net_response =
      map
        (host: {
          protocol = "tcp";
          address = "${host}:22";
          tags.host = host;
          tags.org = "uni";
          send = "SSH-2.0-Telegraf";
          expect = "SSH-2.0";
          timeout = "10s";
        })
        urls;

    x509_cert = [
      {
        sources = [ "https://web.dse.in.tum.de:443" ];
        tags.host = "vmbhatotia19";
        tags.org = "uni";
      }
    ];
  };
  sops.secrets.telegraf.owner = config.systemd.services.telegraf.serviceConfig.User;
  services.telegraf.environmentFiles = [
    config.sops.secrets.telegraf.path
  ];
}
