import { readFileSync } from "node:fs";
import { parseFrontmatter, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

type GroupedSkill = { name: string; path: string };

// Registers /principle-<group> for every group named in a skill's frontmatter:
//
//   metadata:
//     group: code, review
//
// The command tells the agent to read every skill in the group.
export default function (pi: ExtensionAPI): void {
	pi.on("session_start", () => {
		for (const [group, skills] of skillGroups(pi)) {
			pi.registerCommand(`principle-${group}`, {
				description: `Load the ${group} skills: ${skills.map((skill) => skill.name).join(", ")}`,
				handler: async (args, ctx) => {
					const message = loadSkillsMessage(skills, args);
					if (ctx.isIdle()) pi.sendUserMessage(message);
					else pi.sendUserMessage(message, { deliverAs: "steer" });
				},
			});
		}
	});
}

function skillGroups(pi: ExtensionAPI): Map<string, GroupedSkill[]> {
	const groups = new Map<string, GroupedSkill[]>();
	for (const command of pi.getCommands()) {
		if (command.source !== "skill") continue;
		const path = command.sourceInfo.path;
		const { frontmatter } = parseFrontmatter<{ name?: string; metadata?: { group?: unknown } }>(readFileSync(path, "utf8"));
		const group = frontmatter.metadata?.group;
		if (typeof group !== "string") continue;
		const skill = { name: frontmatter.name ?? command.name.replace(/^skill:/, ""), path };
		for (const name of group.split(",").map((part) => part.trim()).filter(Boolean)) {
			groups.set(name, [...(groups.get(name) ?? []), skill]);
		}
	}
	return groups;
}

function loadSkillsMessage(skills: GroupedSkill[], args: string): string {
	const list = skills.map((skill) => `- ${skill.name} (${skill.path})`).join("\n");
	const task = args.trim() ? `\n\n${args.trim()}` : "";
	return `Read these skills and apply them to the work in this session:\n\n${list}${task}`;
}
