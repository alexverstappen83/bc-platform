SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help prereqs seed kubeconfig bootstrap verify up vm-down vm-nuke install-autostart uninstall

help: ## Toon deze hulp
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

prereqs: ## Check tooling op de Mac + toon de eenmalige VM-setup
	@bash host/00-prereqs.sh

seed: ## Bouw de cloud-init seed.iso (koppel je in UTM als 2e drive)
	@bash vm/make-seed-iso.sh

kubeconfig: ## Haal kubeconfig uit de VM en herschrijf het server-IP
	@bash host/20-fetch-kubeconfig.sh

bootstrap: ## Installeer MetalLB, Traefik, Portainer, Technitium
	@bash host/30-bootstrap.sh

verify: ## Controleer elke laag
	@bash host/90-verify.sh

up: kubeconfig bootstrap verify ## Alles-in-één (VM moet al draaien in UTM)

vm-down: ## Stop de VM
	@utmctl stop k3s-server || true

vm-nuke: ## Verwijder de VM (destructief!)
	@utmctl stop k3s-server 2>/dev/null || true; utmctl delete k3s-server || true

install-autostart: ## Zet de VM op autostart bij boot
	@utmctl autostart k3s-server on 2>/dev/null && echo "Autostart aan" || \
	  echo "utmctl autostart niet beschikbaar — zet 'Start on boot' aan in UTM (zie docs/runbook.md)"

uninstall: ## Verwijder cluster-resources (VM blijft bestaan)
	@bash scripts/uninstall.sh
