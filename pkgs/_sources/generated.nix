# This file was generated by nvfetcher, please do not modify it manually.
{
  fetchgit,
  fetchurl,
  fetchFromGitHub,
  dockerTools,
}: {
  source-emacs-lsp-booster = {
    pname = "source-emacs-lsp-booster";
    version = "59f42abb419829f5bcde103d0b18616779ea05f3";
    src = fetchFromGitHub {
      owner = "blahgeek";
      repo = "emacs-lsp-booster";
      rev = "59f42abb419829f5bcde103d0b18616779ea05f3";
      fetchSubmodules = false;
      sha256 = "sha256-xAkYVzDf5fRUQQf3qZ5jicngPemfGdbDknjawlz/A+Q=";
    };
    date = "2024-11-30";
  };
  source-emacs-master-igc = {
    pname = "source-emacs-master-igc";
    version = "b5c4da2ed82330dea65f40074f1814e9a9d70922";
    src = fetchFromGitHub {
      owner = "emacs-mirror";
      repo = "emacs";
      rev = "b5c4da2ed82330dea65f40074f1814e9a9d70922";
      fetchSubmodules = false;
      sha256 = "sha256-diWe8kNWYPuzpbhEIwbRtHiUYOHqUsIxn8jNQ3yWhQg=";
    };
    date = "2025-01-03";
  };
}
