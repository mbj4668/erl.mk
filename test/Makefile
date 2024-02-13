LUX ?= lux

test:
	$(LUX) .

clean:
	for d in $(wildcard lux/*); do \
	  if [ -f $$d/Makefile ]; then \
	    make -C $$d distclean; \
	  fi; \
	  rm -f $$d/erl.mk; \
	done; \
	rm -rf lux_logs

