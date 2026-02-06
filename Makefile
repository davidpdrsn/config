.DEFAULT_GOAL := switch

.PHONY: switch
switch:
	@if [ "$$(uname)" = "Darwin" ]; then \
		sudo darwin-rebuild switch --flake ".#$$(scutil --get LocalHostName)"; \
	else \
		sudo nixos-rebuild switch --flake ".#$$(hostname)"; \
	fi

.PHONY: check
check:
	@nix flake check

.PHONY: build
build:
	@if [ "$$(uname)" = "Darwin" ]; then \
		darwin-rebuild build --flake ".#$$(scutil --get LocalHostName)"; \
	else \
		nixos-rebuild build --flake ".#$$(hostname)"; \
	fi

.PHONY: update
update:
	@./scripts/nix-update-input

.PHONY: compare-updates
compare-updates:
	@./scripts/nix-compare-updates

.PHONY: clone-dev-tools
clone-dev-tools:
	@./scripts/clone-dev-tools

.PHONY: switch-vps
switch-vps:
	ssh -t hetzner-nixos "cd /home/davidpdrsn/config && jj git fetch && jj new main && make switch"
