{
  config,
  lib,
  nu_scripts,
  ...
}:
let
  cfg = config.modules.shell;
  workAliasesFile = "/etc/agenix/alias-for-work.nushell";
in
{
  options.modules.shell = {
    workAliases.enable =
      lib.mkEnableOption "the work aliases from ${workAliasesFile} when that file exists"
      // {
        default = true;
      };
    zai.enable = lib.mkEnableOption "Claude Code with ZAI when ZAI_API_KEY is available" // {
      default = true;
    };
  };

  config.programs.nushell.extraConfig =
    # Nushell resolves `source` while parsing, so a missing work file must be skipped.
    lib.optionalString cfg.workAliases.enable ''
      const work_aliases = if ("${workAliasesFile}" | path exists) {
        "${workAliasesFile}"
      } else {
        null
      }
      source $work_aliases
    ''
    + ''
      $env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
      $env.CLAUDE_CODE_ATTRIBUTION_HEADER = "0"
      # using claude-code with kimi k2
      # https://platform.moonshot.cn/docs/guide/agent-support
      # $env.ANTHROPIC_BASE_URL = "https://api.moonshot.cn/anthropic/"
      # $env.ANTHROPIC_AUTH_TOKEN = $env.MOONSHOT_API_KEY
      # $env.ANTHROPIC_MODEL = "kimi-k2-thinking"
      # $env.ANTHROPIC_DEFAULT_HAIKU_MODEL = "kimi-k2-thinking-turbo"
    ''
    + lib.optionalString cfg.zai.enable ''
      # using claude-code with glm llm
      # https://docs.bigmodel.cn/cn/coding-plan/tool/claude
      if ($env.ZAI_API_KEY? | default "" | str trim | is-not-empty) {
        $env.ANTHROPIC_BASE_URL = "https://open.bigmodel.cn/api/anthropic"
        $env.ANTHROPIC_AUTH_TOKEN = $env.ZAI_API_KEY
        $env.ANTHROPIC_MODEL = "glm-4.7"
        $env.ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.5-air"
      }
    ''
    + ''
      # using claude-code with qwen llm
      # https://bailian.console.aliyun.com/?tab=doc#/doc/?type=model&url=2949529
      # $env.ANTHROPIC_BASE_URL = "https://dashscope.aliyuncs.com/apps/anthropic"
      # $env.ANTHROPIC_AUTH_TOKEN = $env.DASHSCOPE_API_KEY
      # $env.ANTHROPIC_MODEL = "qwen-plus" # 千万别用 qwen-max, 价格
      # $env.ANTHROPIC_DEFAULT_HAIKU_MODEL = "qwen-turbo"

      # Directories in this constant are searched by the
      # `use` and `source` commands.
      const NU_LIB_DIRS = $NU_LIB_DIRS ++ ['${nu_scripts}']

      # -*- completion -*-
      use custom-completions/cargo/cargo-completions.nu *
      use custom-completions/curl/curl-completions.nu *
      use custom-completions/git/git-completions.nu *
      use custom-completions/glow/glow-completions.nu *
      use custom-completions/just/just-completions.nu *
      use custom-completions/make/make-completions.nu *
      use custom-completions/man/man-completions.nu *
      use custom-completions/nix/nix-completions.nu *
      use custom-completions/ssh/ssh-completions.nu *
      use custom-completions/tar/tar-completions.nu *
      use custom-completions/tcpdump/tcpdump-completions.nu *
      use custom-completions/zoxide/zoxide-completions.nu *

      # -*- alias -*-
      use aliases/git/git-aliases.nu *
      use aliases/eza/eza-aliases.nu *
      use aliases/bat/bat-aliases.nu *
      use ${./aliases/gcloud.nu} *

      # -*- modules -*-
      # argx & lg is required by the kubernetes module
      # Keep these imports prefixed so their helpers do not shadow Nushell builtins.
      use modules/argx
      use modules/lg
      # k8s/helm aliases, completions,
      use modules/kubernetes *
      # a wrapper around the jc cli tool, convert cli outputs to nushell tables
      # use modules/jc
    '';
}
