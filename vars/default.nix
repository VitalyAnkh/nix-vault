{lib}: {
  username = "vitalyr";
  userfullname = "VitalyR";
  useremail = "vr@vitalyr.com";
  networking = import ./networking.nix {inherit lib;};
  # generated by `mkpasswd -m scrypt`
  initialHashedPassword = "$y$j9T$t5h5Qa6ZS3WJlLBLRfWg.0$LT6t8G0M0vF4OvDIhdDdvLrhHHQoBAl1nGVez4eIa88";
  # Public Keys that can be used to login to all my PCs, Macbooks, and servers.
  #
  # Since its authority is so large, we must strengthen its security:
  # 1. The corresponding private key must be:
  #    1. Generated locally on every trusted client via:
  #      ```bash
  #      # KDF: bcrypt with 256 rounds, takes 2s on Apple M2):
  #      # Passphrase: digits + letters + symbols, 12+ chars
  #      ssh-keygen -t ed25519 -a 256 -C "ryan@xxx" -f ~/.ssh/xxx`
  #      ```
  #    2. Never leave the device and never sent over the network.
  # 2. Or just use hardware security keys like Yubikey/CanoKey.
  sshAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAI7hWDjjuTEXcd1pckYak39KkQWtuI/jvVeDgAz0CwP vitalyr@eva"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPoa9uEI/gR5+klqTQwvCgD6CD5vT5iD9YCNx2xNrH3B ryan@fern"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPwZ9MdotnyhxIJrI4gmVshExHiZOx+FGFhcW7BaYkfR ryan@harmonica"
  ];
}
