all: $(BINS)

BINS += bin/sbsign
BINS += bin/sign-efi-sig-list

bin/sbsign: sbsigntools/Makefile
	$(MAKE) -C sbsigntools
	cp sbsigntools/src/sbsign $@
sbsigntools/Makefile: sbsigntools/autogen.sh
	cd $(dir $@) ; ./autogen.sh && configure
sbsigntools/autogen.sh:
	git submodule init --recursive sbsigntools

bin/sign-efi-sig-list: efitools/Makefile
	$(MAKE) -C efitools
efitools/Makefile:
	git submodule init --recursive efitools
	
	
