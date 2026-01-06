.DEFAULT_GOAL := switch

.PHONY: switch
switch:
	@sudo darwin-rebuild switch --flake .
