import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Key, matchesKey, truncateToWidth } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const QuestionSchema = Type.Object({
	id: Type.Optional(Type.String({ description: "Stable identifier for the question" })),
	question: Type.String({ description: "Question shown to the user" }),
	options: Type.Optional(
		Type.Array(Type.String({ description: "A choice the user can pick" }), {
			description:
				"Optional multiple-choice options. If provided, the UI shows a picker and an extra final option for custom text input.",
		}),
	),
	multiple: Type.Optional(
		Type.Boolean({
			description:
				"If true, user can select multiple options (Space toggles, Enter confirms selected options).",
		}),
	),
});

const QuestionnaireSchema = Type.Object({
	questions: Type.Array(QuestionSchema, {
		description: "Questions to ask in order. The wizard asks one-by-one and returns all collected answers.",
	}),
});

interface QuestionInput {
	id?: string;
	question: string;
	options?: string[];
	multiple?: boolean;
}

interface QuestionAnswer {
	id: string;
	question: string;
	answer: string | string[];
	kind: "choice" | "custom" | "text" | "multi";
}

interface QuestionnaireDetails {
	skipped: boolean;
	cancelled: boolean;
	answers: QuestionAnswer[];
}

async function askMultiLineAnswer(
	ctx: { ui: { editor: (title: string, text: string) => Promise<string | undefined> } },
	title: string,
): Promise<string | undefined> {
	return ctx.ui.editor(title, "");
}

function formatAnswersForModel(details: QuestionnaireDetails): string {
	if (details.skipped) {
		return "Questionnaire skipped because UI is unavailable.";
	}

	if (details.cancelled) {
		return "User cancelled the questionnaire.";
	}

	if (details.answers.length === 0) {
		return "Questionnaire finished with no answers.";
	}

	return details.answers.map((a, i) => `${i + 1}. ${a.id}: ${JSON.stringify(a.answer)}`).join("\n");
}

export default function (pi: ExtensionAPI): void {
	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt:
				event.systemPrompt +
				"\n\n[Question-asking policy]\n- Do not ask the user direct questions in normal assistant text.\n- If you need clarification, requirements, or a decision from the user, call the questionnaire tool instead.\n- Keep questionnaire questions concrete and minimal, and include options whenever possible.\n- In plan mode, questionnaire is allowed and encouraged for plan clarifications.\n- Exception: do not use questionnaire to ask the user to exit plan mode (for exact `go` or /plan). Ask that directly in assistant text.",
		};
	});

	pi.registerTool({
		name: "questionnaire",
		label: "Questionnaire",
		description:
			"Ask the user one or more clarification questions in a wizard. Supports single-choice, multi-select, and free-text answers.",
		parameters: QuestionnaireSchema,
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const questions = params.questions as QuestionInput[];

			if (!ctx.hasUI) {
				const details: QuestionnaireDetails = {
					skipped: true,
					cancelled: false,
					answers: [],
				};
				return {
					content: [{ type: "text", text: formatAnswersForModel(details) }],
					details,
				};
			}

			const answers: QuestionAnswer[] = [];

			for (let i = 0; i < questions.length; i++) {
				const q = questions[i];
				const id = q.id && q.id.trim().length > 0 ? q.id : `q${i + 1}`;
				const options = (q.options ?? []).filter((opt) => opt.trim().length > 0);
				const isMulti = q.multiple === true;

				if (options.length > 0) {
					if (isMulti) {
						const customOption = "Type custom answer...";
						const allOptions = [...options, customOption];
						const picked = await ctx.ui.custom<string[] | undefined>((tui, theme, _kb, done) => {
							let selectedIndex = 0;
							const selected = new Set<number>();
							let cachedLines: string[] | undefined;

							function refresh() {
								cachedLines = undefined;
								tui.requestRender();
							}

							return {
								handleInput(data: string) {
									if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p")) || data === "k") {
										selectedIndex = Math.max(0, selectedIndex - 1);
										refresh();
										return;
									}
									if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n")) || data === "j") {
										selectedIndex = Math.min(allOptions.length - 1, selectedIndex + 1);
										refresh();
										return;
									}
									if (matchesKey(data, Key.space)) {
										if (selected.has(selectedIndex)) selected.delete(selectedIndex);
										else selected.add(selectedIndex);
										refresh();
										return;
									}
									if (matchesKey(data, Key.enter)) {
										if (selected.size === 0) {
											return;
										}
										done(
											Array.from(selected)
												.sort((a, b) => a - b)
												.map((index) => allOptions[index]),
										);
										return;
									}
									if (matchesKey(data, Key.escape)) {
										done(undefined);
									}
								},
								render(width: number) {
									if (cachedLines) return cachedLines;

									const lines: string[] = [];
									const add = (line: string) => lines.push(truncateToWidth(line, width));

									add(theme.fg("accent", `Question ${i + 1}/${questions.length}`));
									add(q.question);
									lines.push("");

									for (let optionIndex = 0; optionIndex < allOptions.length; optionIndex++) {
										const focused = optionIndex === selectedIndex;
										const marked = selected.has(optionIndex) ? "[x]" : "[ ]";
										const prefix = focused ? theme.fg("accent", "> ") : "  ";
										const text = `${optionIndex + 1}. ${marked} ${allOptions[optionIndex]}`;
										add(prefix + (focused ? theme.fg("accent", text) : text));
									}

									lines.push("");
									add(
										theme.fg(
											"dim",
											"↑/↓, j/k, or Ctrl+P/Ctrl+N navigate • Space toggle • Enter confirm • Esc cancel",
										),
									);
									if (selected.size === 0) {
										add(theme.fg("warning", "Select at least one option before pressing Enter."));
									}

									cachedLines = lines;
									return lines;
								},
								invalidate() {
									cachedLines = undefined;
								},
							};
						});

						if (picked === undefined) {
							const details: QuestionnaireDetails = {
								skipped: false,
								cancelled: true,
								answers,
							};
							return {
								content: [{ type: "text", text: formatAnswersForModel(details) }],
								details,
							};
						}

						const selectedValues = picked.filter((value) => value !== customOption);
						if (picked.includes(customOption)) {
							const custom = await askMultiLineAnswer(
								ctx,
								`Custom answer for:\n${q.question}\n\n(Use editor for multiline input. Empty answer is allowed.)`,
							);
							if (custom === undefined) {
								const details: QuestionnaireDetails = {
									skipped: false,
									cancelled: true,
									answers,
								};
								return {
									content: [{ type: "text", text: formatAnswersForModel(details) }],
									details,
								};
							}
							selectedValues.push(custom);
						}

						answers.push({
							id,
							question: q.question,
							answer: selectedValues,
							kind: "multi",
						});
					} else {
						const customOption = "Type custom answer...";
						const allOptions = [...options, customOption];
						const choice = await ctx.ui.custom<string | undefined>((tui, theme, _kb, done) => {
							let selectedIndex = 0;
							let cachedLines: string[] | undefined;

							function refresh() {
								cachedLines = undefined;
								tui.requestRender();
							}

							return {
								handleInput(data: string) {
									if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p")) || data === "k") {
										selectedIndex = Math.max(0, selectedIndex - 1);
										refresh();
										return;
									}
									if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n")) || data === "j") {
										selectedIndex = Math.min(allOptions.length - 1, selectedIndex + 1);
										refresh();
										return;
									}
									if (matchesKey(data, Key.enter)) {
										done(allOptions[selectedIndex]);
										return;
									}
									if (matchesKey(data, Key.escape)) {
										done(undefined);
									}
								},
								render(width: number) {
									if (cachedLines) return cachedLines;

									const lines: string[] = [];
									const add = (line: string) => lines.push(truncateToWidth(line, width));

									add(theme.fg("accent", `Question ${i + 1}/${questions.length}`));
									add(q.question);
									lines.push("");

									for (let optionIndex = 0; optionIndex < allOptions.length; optionIndex++) {
										const selected = optionIndex === selectedIndex;
										const prefix = selected ? theme.fg("accent", "> ") : "  ";
										const text = `${optionIndex + 1}. ${allOptions[optionIndex]}`;
										add(prefix + (selected ? theme.fg("accent", text) : text));
									}

									lines.push("");
									add(theme.fg("dim", "↑/↓, j/k, or Ctrl+P/Ctrl+N to navigate • Enter to select • Esc to cancel"));

									cachedLines = lines;
									return lines;
								},
								invalidate() {
									cachedLines = undefined;
								},
							};
						});

						if (choice === undefined) {
							const details: QuestionnaireDetails = {
								skipped: false,
								cancelled: true,
								answers,
							};
							return {
								content: [{ type: "text", text: formatAnswersForModel(details) }],
								details,
							};
						}

						if (choice === customOption) {
							const custom = await askMultiLineAnswer(
								ctx,
								`Custom answer for:\n${q.question}\n\n(Use editor for multiline input. Empty answer is allowed.)`,
							);
							if (custom === undefined) {
								const details: QuestionnaireDetails = {
									skipped: false,
									cancelled: true,
									answers,
								};
								return {
									content: [{ type: "text", text: formatAnswersForModel(details) }],
									details,
								};
							}

							answers.push({
								id,
								question: q.question,
								answer: custom,
								kind: "custom",
							});
						} else {
							answers.push({
								id,
								question: q.question,
								answer: choice,
								kind: "choice",
							});
						}
					}
				} else {
					const answer = await askMultiLineAnswer(
						ctx,
						`Question ${i + 1}/${questions.length}\n${q.question}\n\n(Use editor for multiline input. Empty answer is allowed.)`,
					);
					if (answer === undefined) {
						const details: QuestionnaireDetails = {
							skipped: false,
							cancelled: true,
							answers,
						};
						return {
							content: [{ type: "text", text: formatAnswersForModel(details) }],
							details,
						};
					}

					answers.push({
						id,
						question: q.question,
						answer,
						kind: "text",
					});
				}
			}

			const details: QuestionnaireDetails = {
				skipped: false,
				cancelled: false,
				answers,
			};

			return {
				content: [
					{
						type: "text",
						text: formatAnswersForModel(details),
					},
				],
				details,
			};
		},
	});
}
