.DEFAULT_GOAL := switch

.PHONY: switch
switch:
	@sudo darwin-rebuild switch --flake .

.PHONY: check
check:
	@nix flake check

.PHONY: compare-updates
compare-updates:
	@./scripts/nix-compare-updates
