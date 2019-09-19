PONYCFLAGS ?= --verbose=1 --debug

messages.pony: messages.wproto ../wprotocol.py ../wprotocol_specs.py
	@echo Generating messages.pony from messages.wproto.
	@python3 ../wprotocol.py $(shell pwd) > messages.pony

test: messages
	./pony_tests

messages: _test.pony messages.pony
	stable env ponyc $(PONYCFLAGS)

clean:
	@rm -f messages.pony
