{...}: {
  programs.ripgrep = {
    enable = true;
    arguments = [
      # Search hidden files / directories (e.g. dotfiles) by default
      "--hidden"
      # Search files in .gitignore
      "--no-ignore"
      # Using glob patterns to include/exclude files or folders
      "--glob=!.git/*"
      "--glob=!.jj/*"
      "--glob=!node_modules"
      "--glob=!.godot/*"
      "--glob=!.pi/tmp/*"
      "--glob=!build"
      "--glob=!builds"
      "--glob=!.cache"
      "--glob=!.turbo"
      "--glob=!.svelte-kit"
      "--glob=!.git"
      "--glob=!.go"
      "--glob=!.direnv"
      "--glob=!.pnpm-global"
      "--glob=!temp"
      "--glob=!*\.map"
      "--glob=!target"
      "--glob=!*\.log"
      "--glob=!*\.DS_Store"
      "--glob=!*\.js"
      "--glob=!*\.d\.ts"
      "--glob=!release"
      "--glob=!generated-archives"
      "--glob=!generated-do-not-edit"
      "--glob=!cli-docs"
      "--glob=!dist"
      "--glob=!dist-ssr"
      "--glob=!package"
      "--glob=!.pnpm-store"
      "--glob=!test-results*"
      "--glob=!playwright-report"
      "--glob=!storybook-static"
      "--glob=!.vercel"
      "--glob=!.rust-analyzer"
      "--glob=!.agents/*"
      "--glob=!.claude/*"
      # Because who cares about case!?
      "--smart-case"
    ];
  };
}
