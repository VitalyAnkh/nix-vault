# Emacs Editor

## Why emacs?

1. Explore the unknown, just for fun!
2. Org Mode
3. Lisp Coding
4. A top-level tutorial for Emacs(Chinese): <https://nyk.ma/tags/emacs/>
5. A Beginner's Guide to Emacs(Chinese):
   <https://github.com/emacs-tw/emacs-101-beginner-survival-guide>

## Screenshot

![](/_img/emacs-2024-01-07.webp)

## Useful Links

- Framework: <https://github.com/doomemacs/doomemacs>
  - key bindings:
    - source code:
      <https://github.com/doomemacs/doomemacs/blob/master/modules/config/default/%2Bevil-bindings.el>
    - docs: <https://github.com/doomemacs/doomemacs/blob/master/modules/editor/evil/README.org>
  - module index: <https://github.com/doomemacs/doomemacs/blob/master/docs/modules.org>
- LSP Client: <https://github.com/manateelazycat/lsp-bridge>
- Emacs Wiki: <https://www.emacswiki.org/emacs/SiteMap>
- Awesome Emacs: <https://github.com/emacs-tw/awesome-emacs#lsp-client>
- Chinese(rime) support: <https://github.com/DogLooksGood/emacs-rime>
- modal editing:
  - <https://github.com/emacs-evil/evil>: evil mode, enabled by default in doom-emacs.
  - <https://github.com/meow-edit/meow>

## Install or Update

`modules.editors.emacs.enable` installs the repository's Emacs package, `emacs-lsp-booster`, and the
`e` / `et` client aliases. Doom management and the daemon have separate switches:

```nix
modules.editors.emacs = {
  enable = true;
  doom.enable = false;
  daemon.enable = false;
};
```

`doom.enable` defaults to `true`. It installs Doom dependencies, copies the pinned Doom source to
the Emacs configuration directory, links `~/.config/doom` to the configuration in
`~/projects/dev/emacs-projects/doom`, and adds Doom's `bin` directory to PATH in Bash, Zsh and Fish.
Emacs starts from `~/.emacs.d`, `~/.emacs` or `~/.emacs.el` instead whenever one of them exists;
activation removes an empty `~/.emacs.d`, which Emacs creates when it runs before Doom is installed,
and warns about the others. When it is disabled, this module does not manage Doom files or add its
dependencies and PATH.

Doom's modules live in its git submodule `sources/doom+`. GitHub tarballs omit submodules, so the
`doomemacs` flake input is a git input with `submodules=1`; without the modules, Doom loads only its
core and none of the modules enabled in `init.el`.

The copied Doom source carries `doom-straight-dependency-versions.patch`. The Doom configuration
unpins straight.el, whose build cache records each dependency with its minimum version; without the
patch, `doom sync` fails with `(wrong-type-argument listp "9.7")` while generating the profile's
init file. Drop the patch once the pinned Doom reads these records itself: the build fails when the
patch no longer applies.

The Emacs package in `pkgs/emacs` carries a backport of the fix for Emacs bug#81906, which the IGC
branch lacks. Without it, the obsolete `make-autoload` fails on every autoload cookie; Doom uses it
to generate its autoloads, so every `doom` command fails with
`cl-assertion-failed: ((> (point) output-start))`.

On macOS, `pkgs/emacs` also applies `ns-accessibility-buffer-text.patch`, a local fix with no
upstream reference. Without it, Emacs answers the accessibility attributes `AXValue` and
`AXSelectedText` from the selected frame rather than the queried window, takes the region from the
global PRIMARY selection, and copies raw buffer bytes, so an accessibility client such as VoiceOver
can receive another window's text or bytes from the buffer gap. The patch reads the queried window's
own buffer and region through the buffer-substring helper. Drop it once the pinned Emacs source
handles these attributes the same way; the build fails when the patch no longer applies.

`daemon.enable` defaults to `true` on macOS and `false` on Linux. It controls the launchd agent on
macOS and the Home Manager Emacs user service on Linux. With the daemon disabled, start Emacs
directly or start a daemon manually before using `e` / `et`.

When Doom management is enabled, run the following command after deploying this nix flake to install
or update Doom packages:

```bash
doom sync
```

when in doubt, run `doom sync`!

## Testing

> via `justfile` located at the root of this repo. These recipes run `doom`, so they need Doom
> management; `emacs-reload` also restarts the daemon, so it needs `daemon.enable`.

```bash
just emacs-test
just emacs-purge
just emacs-reload
```

## Limits

- It's too slow to start up and install(compile/build) packages.
  - I have to use emacs in daemon/client mode to avoid this issue.
- It's too large in size, not suitable for servers.
  - So vim/neovim is still the best choice for servers.
- Emacs's markdown-mode works not well with tables, see:
  - https://github.com/jrblevin/markdown-mode/issues/380
- I use git command frequently, but doomemacs only autoupdates status of git diff / treemacs when
  using magit.
  - I have to learn magit to avoid this issue...
- GitHub's orgmode support is not well, Markdown is better for GitHub.
  - Use markdown for repo's README.md, and use orgmode for my personal notes and docs only.

## Cheatsheet

Here is the cheatsheet related to my DoomEmacs configs. Please read vim's common cheatsheet at
[../README.md](../README.md) before reading the following.

### Basics

> Terminal(vterm) is useful in GUI mode, I use Zellij instead in terminal mode.

| Action                 | Shortcut                                          |
| ---------------------- | ------------------------------------------------- |
| Popup Terminal(vterm)  | `SPC + o + t`                                     |
| Open Terminal          | `SPC + o + T`                                     |
| Open file tree sidebar | `SPC + o + p`                                     |
| Frame fullscreen       | `SPC + t + F`                                     |
| Exit                   | `M-x C-c`                                         |
| Execute Command        | `M-x`(hold on `Alt`/`option`, and then press `x`) |
| Eval Lisp Code         | `M-:`(hold on `Alt`/`option`, and then press `:`) |

### Window Navigation

| Action                                     | Shortcut                                                              |
| ------------------------------------------ | --------------------------------------------------------------------- |
| Split a window vertically and horizontally | `SPC w v/s`                                                           |
| Move to a window in a specific direction   | `Ctrl-w + h/j/k/l`                                                    |
| Move a window to a specific direction      | `Ctrl-w + H/J/K/L`                                                    |
| Move to the next window                    | `SPC w w`                                                             |
| Close the current window                   | `SPC w q`                                                             |
| Rebalance all windows                      | `SPC w =`                                                             |
| Set window's width(columns)                | `80 SPC w \|` (the Vertical line is escaped due to markdown's limits) |
| Set window's height                        | `30 SPC w _ `                                                         |

### File Tree

- treemacs: <https://github.com/Alexander-Miller/treemacs/blob/master/src/elisp/treemacs-mode.el>
- treemacs-evil:
  <https://github.com/Alexander-Miller/treemacs/blob/master/src/extra/treemacs-evil.el>

| Action                                | Shortcut  |
| ------------------------------------- | --------- |
| Resize Treemacs's window              | `>` & `<` |
| Extra Wide Window                     | `W`       |
| Rename                                | `R`       |
| Delete File/Direcoty                  | `d`       |
| New File                              | `cf`      |
| New Directory                         | `cd`      |
| Go to parent                          | `u`       |
| Run shell command in for current node | `!`       |
| Refresh file tree                     | `gr`      |
| Copy project-path into pasteboard     | `yp`      |
| Copy absolute-path into pasteboard    | `ya`      |
| Copy relative-path into pasteboard    | `yr`      |
| Copy file to another location         | `yf`      |
| Move file to another location         | `m`       |
| quit                                  | `q`       |

And bookmarks:

- Add bookmarks in treemacs: `b`
- Show Bookmark List: `SPC s m`

### Splitting and Buffers

| Action                  | Shortcut          |
| ----------------------- | ----------------- |
| Buffer List             | `<Space> + ,`     |
| Save all buffers(Tab)   | `<Space> + b + S` |
| Kill the current buffer | `<Space> + b + k` |
| Kill all buffers        | `<Space> + b + K` |

### Editing and Formatting

| Action                                     | Shortcut            |
| ------------------------------------------ | ------------------- |
| Format Document                            | `<Space> + cf`      |
| Code Actions                               | `<Space> + ca`      |
| Rename                                     | `<Space> + cr`      |
| Opening LSP symbols                        | `<Space> + cS`      |
| Show all LSP Errors                        | `<Space> + c + x/X` |
| Show infinite undo history(really useful!) | `<Space> + s + u`   |
| Open filepath/URL at cursor                | `gf`                |
| Find files by keyword in path              | `<Space> + <Space>` |
| Grep string in files (vertico + ripgrep)   | `<Space> + sd`      |

### Image Preview(GUI mode only)

Use `-`, `+` to resize the image, `r` to rotate the image.

### Search & replace

```bash
SPC s p foo C-; E C-c C-p :%s/foo/bar/g RET Z Z
```

1. `SPC s p`: search in project
1. `foo`: the keyword to search
1. `C-; E`: exports what you’re looking at into a new buffer in grep-mode
1. `C-c C-p` to run wgrep-change-to-wgrep-mode to make the search results writable.
1. `:%s/foo/bar/g RET`: replace in the current buffer(just like neovim/vim)
1. `Z Z`: to write all the changes to their respective files

### Projects

> easily switch between projects without exit emacs!

| Action                     | Shortcut      |
| -------------------------- | ------------- |
| Switch between projects    | `SPC + p + p` |
| Browse the current project | `SPC + p + .` |
| Add new project            | `SPC + p + a` |

### Workspaces

> Very useful when run emacs in daemon/client modes

| Action                      | Shortcut                    |
| --------------------------- | --------------------------- |
| Switch between workspaces   | `M-1/2/3/...`(Alt-1/2/3/..) |
| New Workspace               | `SPC + TAB + n`             |
| New Named Workspace         | `SPC + TAB + N`             |
| Delete Workspace            | `SPC + TAB + d`             |
| Display Workspaces bar blow | `SPC + TAB + TAB`           |

### Magit

> https://github.com/magit/magit

Magit is a powerful tool that make git operations easy and intuitive.

| Action                   | Shortcut                 |
| ------------------------ | ------------------------ |
| Open Magit               | `C-x g` or `SPC + g + g` |
| Switch branch            | `SPC + g + b`            |
| Show buffer's commit log | `SPC + g + L`            |

Shortcuts in magit's pane:

> When run `git commit` / `git add` / `git push` /... via magit, multiple Arguments can be set. Set
> arguments won't trigger a git command immediately. Magit will try to run a git command only after
> an Action key is pressed.

| Action                                             | Shortcut                                      |
| -------------------------------------------------- | --------------------------------------------- |
| Quit the current Magit pane                        | `q`                                           |
| Show log                                           | `l`                                           |
| Show current branch's log                          | `l + l`                                       |
| Show current reflog                                | `l + r`                                       |
| Commit                                             | `c`                                           |
| Stage                                              | `s`                                           |
| Unstage                                            | `u`                                           |
| Push                                               | `p`                                           |
| Pull                                               | `f`                                           |
| Rebase                                             | `r`                                           |
| Rebase Interactively                               | `r + i`, select on a commit, then `C-c + C-c` |
| Stash                                              | `z`                                           |
| Merge                                              | `m`                                           |
| Fold/Unfold                                        | `TAB`                                         |
| Show details of the current unit(commit/stage/...) | `<ENTER>`                                     |

KeyBinding full list:
<https://github.com/emacs-evil/evil-collection/tree/master/modes/magit#key-bindings>
