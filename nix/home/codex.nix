{config, lib, pkgs, ...}: let
  piPromptsDir = ../../pi/prompts;
  piPromptFiles = lib.filterAttrs
    (name: type: type == "regular" && lib.hasSuffix ".md" name)
    (builtins.readDir piPromptsDir);
  codexSkillFiles = lib.mapAttrs'
    (fileName: _: let
      name = lib.removeSuffix ".md" fileName;
    in
      lib.nameValuePair name (pkgs.writeText "codex-skill-${name}.md" ''
        ---
        name: ${name}
        description: Run the ${name} workflow
        ---

        ${builtins.readFile "${piPromptsDir}/${fileName}"}
      ''))
    piPromptFiles;
  generatedCodexSkills = pkgs.runCommand "codex-skills-from-pi-prompts" {} (''
      mkdir -p "$out"
    ''
    + lib.concatStringsSep "\n" (lib.mapAttrsToList (name: skillFile: ''
        mkdir -p "$out/${name}"
        cp ${skillFile} "$out/${name}/SKILL.md"
        touch "$out/${name}/.pi-prompt-generated"
      '') codexSkillFiles));
in {
  home.file.".codex/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/config/codex/config.toml";

  # Codex ignores individually symlinked SKILL.md files, so materialize these
  # generated skills as regular files while leaving other Codex skills alone.
  home.activation.installCodexPromptSkills = lib.hm.dag.entryAfter ["linkGeneration"] ''
    skills_dir="${config.home.homeDirectory}/.codex/skills"
    mkdir -p "$skills_dir"

    for skill_dir in "$skills_dir"/*; do
      if [ -f "$skill_dir/.pi-prompt-generated" ]; then
        rm -rf "$skill_dir"
      fi
    done

    for skill_dir in ${generatedCodexSkills}/*; do
      skill_name="$(${pkgs.coreutils}/bin/basename "$skill_dir")"
      destination="$skills_dir/$skill_name"

      if [ -e "$destination" ]; then
        echo "Refusing to replace non-generated Codex skill: $destination" >&2
        exit 1
      fi

      cp -R "$skill_dir" "$destination"
      chmod -R u+w "$destination"
    done
  '';
}
