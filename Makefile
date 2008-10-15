PREFIX = /usr/local
EXEDIR = /bin

LIBOBJS = hugeutils.o version.o init.o morecore.o debug.o alloc.o shm.o kernel-features.o
INSTALL_OBJ_LIBS = libhugetlbfs.so libhugetlbfs.a
BIN_OBJ_DIR=obj
INSTALL_BIN = hugectl hugeedit hugeadm pagesize
INSTALL_HEADERS = hugetlbfs.h
INSTALL_MAN1 = pagesize.1
INSTALL_MAN3 = get_huge_pages.3 gethugepagesizes.3 getpagesizes.3
INSTALL_MAN7 = libhugetlbfs.7
INSTALL_MAN8 = hugectl.8 hugeedit.8 hugeadm.8
LDSCRIPT_TYPES = B BDT
LDSCRIPT_DIST_ELF = elf32ppclinux elf64ppc elf_i386 elf_x86_64
INSTALL_OBJSCRIPT = ld.hugetlbfs
VERSION=version.h
SOURCE = $(shell find . -maxdepth 1 ! -name version.h -a -name '*.[h]')
SOURCE += *.c *.lds Makefile
NODEPTARGETS=<version.h> <clean>

INSTALL = install

LDFLAGS += --no-undefined-version -Wl,--version-script=version.lds -ldl
CFLAGS ?= -O2 -g
CFLAGS += -Wall -fPIC
CPPFLAGS += -D__LIBHUGETLBFS__

ARCH = $(shell uname -m | sed -e s/i.86/i386/)

ifeq ($(ARCH),ppc64)
CC64 = gcc -m64
ELF64 = elf64ppc
LIB64 = lib64
LIB32 = lib
ifneq ($(BUILDTYPE),NATIVEONLY)
CC32 = gcc -m32
ELF32 = elf32ppclinux
endif
else
ifeq ($(ARCH),ppc)
CC32 = gcc -m32
ELF32 = elf32ppclinux
LIB32 = lib
else
ifeq ($(ARCH),i386)
CC32 = gcc
ELF32 = elf_i386
LIB32 = lib
else
ifeq ($(ARCH),x86_64)
CC64 = gcc -m64
ELF64 = elf_x86_64
LIB64 = lib64
LIB32 = lib
ifneq ($(BUILDTYPE),NATIVEONLY)
CC32 = gcc -m32
ELF32 = elf_i386
endif
else
ifeq ($(ARCH),ia64)
CC64 = gcc
LIB64 = lib64
CFLAGS += -DNO_ELFLINK
else
ifeq ($(ARCH),sparc64)
CC64 = gcc -m64
LIB64 = lib64
CFLAGS += -DNO_ELFLINK
else
ifeq ($(ARCH),s390x)
CC64 = gcc -m64
CC32 = gcc -m31
LIB64 = lib64
LIB32 = lib
CFLAGS += -DNO_ELFLINK
else
$(error "Unrecognized architecture ($(ARCH))")
endif
endif
endif
endif
endif
endif
endif

ifdef CC32
OBJDIRS += obj32
endif
ifdef CC64
OBJDIRS +=  obj64
endif

ifdef ELF32
LIBOBJS32 = obj32/elflink.o obj32/sys-$(ELF32).o
endif
ifdef ELF64
LIBOBJS64 = obj64/elflink.o obj64/sys-$(ELF64).o
endif
ifeq ($(ELF32),elf32ppclinux)
LIBOBJS32 += obj32/$(ELF32).o
endif
ifeq ($(ELF64),elf64ppc)
LIBOBJS64 += obj64/$(ELF64).o
endif
LIBOBJS32 += $(LIBOBJS:%=obj32/%)
LIBOBJS64 += $(LIBOBJS:%=obj64/%)

HEADERDIR = $(PREFIX)/include
LIBDIR32 = $(PREFIX)/$(LIB32)
LIBDIR64 = $(PREFIX)/$(LIB64)
LDSCRIPTDIR = $(PREFIX)/share/libhugetlbfs/ldscripts
BINDIR = $(PREFIX)/share/libhugetlbfs
EXEDIR = $(PREFIX)/bin
DOCDIR = $(PREFIX)/share/doc/libhugetlbfs
MANDIR1 = $(PREFIX)/man/man1
MANDIR3 = $(PREFIX)/man/man3
MANDIR7 = $(PREFIX)/man/man7
MANDIR8 = $(PREFIX)/man/man8

ifdef LIB32
LIBPATHS += -DLIB32='"$(LIB32)"' -DLIBDIR32='"$(LIBDIR32)"'
endif
ifdef LIB64
LIBPATHS += -DLIB64='"$(LIB64)"' -DLIBDIR64='"$(LIBDIR64)"'
endif

EXTRA_DIST = \
	README \
	HOWTO \
	LGPL-2.1

INSTALL_LDSCRIPTS = $(foreach type,$(LDSCRIPT_TYPES),$(LDSCRIPT_DIST_ELF:%=%.x$(type)))

ifdef V
VECHO = :
else
VECHO = echo "	"
ARFLAGS = rc
.SILENT:
endif

DEPFILES = $(LIBOBJS:%.o=%.d)

export ARCH
export OBJDIRS
export CC32
export CC64
export ELF32
export ELF64
export LIBDIR32
export LIBDIR64

all:	libs tests tools

.PHONY:	tests libs

libs:	$(foreach file,$(INSTALL_OBJ_LIBS),$(OBJDIRS:%=%/$(file)))

tests:	libs # Force make to build the library first
tests:	tests/all

tests/%:
	$(MAKE) -C tests $*

tools:  $(foreach file,$(INSTALL_BIN),$(BIN_OBJ_DIR)/$(file))

check:	all
	cd tests; ./run_tests.sh

checkv:	all
	cd tests; ./run_tests.sh -vV

func:	all
	cd tests; ./run_tests.sh -t func

funcv:	all
	cd tests; ./run_tests.sh -t func -vV

stress:	all
	cd tests; ./run_tests.sh -t stress

stressv: all
	cd tests; ./run_tests.sh -t stress -vV

# Don't want to remake objects just 'cos the directory timestamp changes
$(OBJDIRS): %:
	@mkdir -p $@

# <Version handling>
$(VERSION): always
	@$(VECHO) VERSION
	./localversion version $(SOURCE)
always:
# </Version handling>

snapshot: $(VERSION)

.SECONDARY:

obj32/%.o: %.c
	@$(VECHO) CC32 $@
	@mkdir -p obj32
	$(CC32) $(CPPFLAGS) $(CFLAGS) -o $@ -c $<

obj64/%.o: %.c
	@$(VECHO) CC64 $@
	@mkdir -p obj64
	$(CC64) $(CPPFLAGS) $(CFLAGS) -o $@ -c $<

obj32/%.o: %.S
	@$(VECHO) AS32 $@
	@mkdir -p obj32
	$(CC32) $(CPPFLAGS) -o $@ -c $<

obj64/%.o: %.S
	@$(VECHO) AS64 $@
	@mkdir -p obj64
	$(CC64) $(CPPFLAGS) -o $@ -c $<

obj32/libhugetlbfs.a: $(LIBOBJS32)
	@$(VECHO) AR32 $@
	$(AR) $(ARFLAGS) $@ $^

obj64/libhugetlbfs.a: $(LIBOBJS64)
	@$(VECHO) AR64 $@
	$(AR) $(ARFLAGS) $@ $^

obj32/libhugetlbfs.so: $(LIBOBJS32)
	@$(VECHO) LD32 "(shared)" $@
	$(CC32) $(LDFLAGS) -Wl,-soname,$(notdir $@) -shared -o $@ $^ $(LDLIBS)

obj64/libhugetlbfs.so: $(LIBOBJS64)
	@$(VECHO) LD64 "(shared)" $@
	$(CC64) $(LDFLAGS) -Wl,-soname,$(notdir $@) -shared -o $@ $^ $(LDLIBS)

obj32/%.i:	%.c
	@$(VECHO) CPP $@
	$(CC32) $(CPPFLAGS) -E $< > $@

obj64/%.i:	%.c
	@$(VECHO) CPP $@
	$(CC64) $(CPPFLAGS) -E $< > $@

obj32/%.s:	%.c
	@$(VECHO) CC32 -S $@
	$(CC32) $(CPPFLAGS) $(CFLAGS) -o $@ -S $<

obj64/%.s:	%.c
	@$(VECHO) CC64 -S $@
	$(CC64) $(CPPFLAGS) $(CFLAGS) -o $@ -S $<

$(BIN_OBJ_DIR)/%.o: %.c
	@$(VECHO) CCHOST $@
	@mkdir -p $(BIN_OBJ_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ -c $<

$(BIN_OBJ_DIR)/hugectl: $(BIN_OBJ_DIR)/hugectl.o
	@$(VECHO) LDHOST $@
	mkdir -p $(BIN_OBJ_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LIBPATHS) -o $@ $^

$(BIN_OBJ_DIR)/hugeedit: $(BIN_OBJ_DIR)/hugeedit.o
	@$(VECHO) LDHOST $@
	mkdir -p $(BIN_OBJ_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LIBPATHS) -o $@ $^

HUGEADM_OBJ=hugeadm.o hugeutils.o debug.o
$(BIN_OBJ_DIR)/hugeadm: $(foreach file,$(HUGEADM_OBJ),$(BIN_OBJ_DIR)/$(file))
	@$(VECHO) LDHOST $@
	mkdir -p $(BIN_OBJ_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LIBPATHS) -o $@ $^

PAGESIZE_OBJ=pagesize.o hugeutils.o debug.o
$(BIN_OBJ_DIR)/pagesize: $(foreach file,$(PAGESIZE_OBJ),$(BIN_OBJ_DIR)/$(file))
	@$(VECHO) LDHOST $@
	mkdir -p $(BIN_OBJ_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LIBPATHS) -o $@ $^

clean:
	@$(VECHO) CLEAN
	rm -f *~ *.o *.so *.a *.d *.i core a.out $(VERSION)
	rm -rf obj*
	rm -f ldscripts/*~
	rm -f libhugetlbfs-sock
	$(MAKE) -C tests clean

%.d: %.c $(VERSION)
	@$(CC) $(CPPFLAGS) -MM -MT "$(foreach DIR,$(OBJDIRS),$(DIR)/$*.o) $@" $< > $@

# Workaround: Don't build dependencies for certain targets
#    When the include below is executed, make will use the %.d target above to
# generate missing files.  For certain targets (clean, version.h, etc) we don't
# need or want these dependency files, so don't include them in this case.
ifeq (,$(findstring <$(MAKECMDGOALS)>,$(NODEPTARGETS)))
-include $(DEPFILES)
endif

obj32/install:
	@$(VECHO) INSTALL32 $(LIBDIR32)
	$(INSTALL) -d $(DESTDIR)$(LIBDIR32)
	$(INSTALL) $(INSTALL_OBJ_LIBS:%=obj32/%) $(DESTDIR)$(LIBDIR32)

obj64/install:
	@$(VECHO) INSTALL64 $(LIBDIR64)
	$(INSTALL) -d $(DESTDIR)$(LIBDIR64)
	$(INSTALL) $(INSTALL_OBJ_LIBS:%=obj64/%) $(DESTDIR)$(LIBDIR64)

objscript.%: %
	@$(VECHO) OBJSCRIPT $*
	sed "s!### SET DEFAULT LDSCRIPT PATH HERE ###!HUGETLB_LDSCRIPT_PATH=$(LDSCRIPTDIR)!" < $< > $@

install: libs tools $(OBJDIRS:%=%/install) $(INSTALL_OBJSCRIPT:%=objscript.%)
	@$(VECHO) INSTALL
	$(INSTALL) -d $(DESTDIR)$(LDSCRIPTDIR)
	$(INSTALL) -d $(DESTDIR)$(HEADERDIR)
	$(INSTALL) -d $(DESTDIR)$(MANDIR7)
	$(INSTALL) -d $(DESTDIR)$(MANDIR8)
	$(INSTALL) -m 644 -t $(DESTDIR)$(HEADERDIR) $(INSTALL_HEADERS)
	$(INSTALL) -m 644 $(INSTALL_LDSCRIPTS:%=ldscripts/%) $(DESTDIR)$(LDSCRIPTDIR)
	$(INSTALL) -d $(DESTDIR)$(BINDIR)
	$(INSTALL) -d $(DESTDIR)$(EXEDIR)
	@$(VECHO) INSTALLBIN $(DESTDIR)$(EXEDIR)
	for x in $(INSTALL_BIN); do \
		$(INSTALL) -m 755 $(BIN_OBJ_DIR)/$$x $(DESTDIR)$(EXEDIR); done
	for x in $(INSTALL_OBJSCRIPT); do \
		$(INSTALL) -m 755 objscript.$$x $(DESTDIR)$(BINDIR)/$$x; done
	@$(VECHO) INSTALLMAN $(DESTDIR)manX
	for x in $(INSTALL_MAN1); do \
		$(INSTALL) -m 444 man/$$x $(DESTDIR)$(MANDIR1); \
		gzip -f $(DESTDIR)$(MANDIR1)/$$x; \
	done
	for x in $(INSTALL_MAN3); do \
		$(INSTALL) -m 444 man/$$x $(DESTDIR)$(MANDIR3); \
		gzip -f $(DESTDIR)$(MANDIR3)/$$x; \
	done
	rm -f $(DESTDIR)$(MANDIR3)/free_huge_pages.3.gz
	ln -s $(DESTDIR)$(MANDIR3)/get_huge_pages.3.gz $(DESTDIR)$(MANDIR3)/free_huge_pages.3.gz
	for x in $(INSTALL_MAN7); do \
		$(INSTALL) -m 444 man/$$x $(DESTDIR)$(MANDIR7); \
		gzip -f $(DESTDIR)$(MANDIR7)/$$x; \
	done
	for x in $(INSTALL_MAN8); do \
		$(INSTALL) -m 444 man/$$x $(DESTDIR)$(MANDIR8); \
		gzip -f $(DESTDIR)$(MANDIR8)/$$x; \
	done
	cd $(DESTDIR)$(BINDIR) && ln -sf ld.hugetlbfs ld

install-docs:
	$(INSTALL) -d $(DESTDIR)$(DOCDIR)
	for x in $(EXTRA_DIST); do $(INSTALL) -m 755 $$x $(DESTDIR)$(DOCDIR)/$$x; done

install-tests: tests install	# Force make to build tests and install the library first
	${MAKE} -C tests install DESTDIR=$(DESTDIR) OBJDIRS="$(OBJDIRS)" LIB32=$(LIB32) LIB64=$(LIB64)
