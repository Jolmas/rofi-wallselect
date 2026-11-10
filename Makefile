SHELL := /bin/bash
DEST  ?= $(HOME)/.config/rofi/wallselect

.PHONY: all help install uninstall thumbs check

all: help

help:
	@echo "rofi-wallselect"
	@echo
	@echo "  make install     Instala script, tema y configuración"
	@echo "  make uninstall   Desinstala (conserva config.sh y la caché)"
	@echo "  make thumbs      Regenera la caché de miniaturas"
	@echo "  make check       Valida el script y el tema de rofi"

install:
	./install.sh

uninstall:
	./uninstall.sh

thumbs:
	$(DEST)/wallselect.sh --generate-thumbs

check:
	bash -n src/wallselect.sh
	rofi -theme src/style.rasi -dump-theme >/dev/null
	@echo "Validación correcta."
