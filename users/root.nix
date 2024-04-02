{config, ...}: {
  config = {
    age.secrets.root-password = {
      file = ../secrets/root-password.age;
    };

    users.users.root = {
      hashedPasswordFile = config.age.secrets.root-password.path;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHW4PIqcucwZdFj5u9aMhLj/ernBFV24PyHuspHwh3LT ramona@moonfall"
      ];
    };
  };
}
