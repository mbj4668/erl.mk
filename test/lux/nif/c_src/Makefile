NIF = ../priv/n.so

all: $(NIF)

include c_src.mk

c_src.mk:
	$(MAKE) -f ../erl.mk $@

SOURCES := $(wildcard *.c)
OBJS := $(SOURCES:%.c=./%.o)

$(NIF): $(OBJS)
	@mkdir -p $(dir $@)
	$(CC) $^ $(LIBS) $(LDFLAGS_NIF) -o $@

clean:
	rm -f $(NIF) ./*.o
