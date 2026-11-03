# Editor-related language servers and heavy tooling — kept out of `core/editors`.
{
  imports = [
    ./ipython
    ./packages.nix
    ./emacs
  ];

  # Upstream's ipython module also writes an ipython_config.py that turns the SQLite
  # history off. Keep IPython's history here (the user's decision, 2026-11-04); the
  # startup helpers stay.
  home.file.".ipython/profile_default/ipython_config.py".enable = false;
}
