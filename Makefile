.DEFAULT_GOAL := switch

.PHONY: switch
switch:
	@sudo darwin-rebuild switch --flake .

.PHONY: check
check:
	@nix flake check

.PHONY: update
update:
	@./scripts/nix-update-input

.PHONY: compare-updates
compare-updates:
	@./scripts/nix-compare-updates
