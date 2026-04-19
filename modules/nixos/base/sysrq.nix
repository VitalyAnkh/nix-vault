{ lib, ... }:
{
  # Enable Magic SysRq key combos (Alt+SysRq+<command>) so REISUB works during
  # partial system hangs.
  #
  # NixOS defaults `kernel.sysrq` to a restrictive value (`16`), which disables
  # most SysRq functions (including reboot).
  #
  # Use `1` to enable **all** SysRq functions.
  #
  # If you want a more restrictive policy (but still allow REISUB), use `244`
  # instead (keyboard control + signal processes + sync + remount RO + reboot).
  boot.kernel.sysctl."kernel.sysrq" = lib.mkForce 1;
}
