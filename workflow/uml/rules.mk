UMLFILES := $(wildcard *.uml)
UMLRESULTS := $(patsubst %.uml,%.png,$(UMLFILES))

default: $(UMLRESULTS)

%.png: %.uml
	plantuml $<
