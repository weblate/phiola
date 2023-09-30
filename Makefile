# phiola Makefile

ROOT_DIR := ..
PHIOLA := $(ROOT_DIR)/phiola
AVPACK := $(ROOT_DIR)/avpack
FFPACK := $(ROOT_DIR)/ffpack
FFOS := $(ROOT_DIR)/ffos
FFBASE := $(ROOT_DIR)/ffbase
APP_DIR := phiola-2

include $(FFBASE)/test/makeconf

SUBMAKE := $(MAKE) -f $(firstword $(MAKEFILE_LIST))
ALIB3 := $(PHIOLA)/alib3
ALIB3_BIN := $(ALIB3)/_$(OS)-$(CPU)
FFPACK_BIN := $(FFPACK)/_$(OS)-$(CPU)

# COMPILER

CFLAGS += -DFFBASE_MEM_ASSERT
CFLAGS += -I$(FFBASE)
CFLAGS += -Wall -Wextra -Wno-unused-parameter -Wno-for-loop-analysis -Wno-multichar
CFLAGS += -g
CFLAGS += -fPIC
ifeq "$(DEBUG)" "1"
	CFLAGS += -DFF_DEBUG -O0 -Werror -Wno-deprecated-declarations
else
	CFLAGS += -O3 -fno-strict-aliasing -fvisibility=hidden
endif
ifeq "$(ASAN)" "1"
	CFLAGS += -fsanitize=address
	LINKFLAGS += -fsanitize=address
endif
CFLAGS_BASE := $(CFLAGS)
CFLAGS += -I$(PHIOLA)/src -I$(FFOS)
CXXFLAGS := $(CFLAGS) -fno-exceptions -fno-rtti -Wno-c++11-narrowing
ifeq "$(OS)" "windows"
	LINKFLAGS += -lws2_32
endif
LINK_DL :=
ifeq "$(OS)" "linux"
	LINK_DL := -ldl
endif

# MODULES

ifneq "$(DEBUG)" "1"
default: strip-debug
	$(SUBMAKE) app
else
default: build
	$(SUBMAKE) app
endif

DEPS := $(PHIOLA)/src/phiola.h \
	$(PHIOLA)/src/track.h

%.o: $(PHIOLA)/src/%.c $(DEPS)
	$(C) $(CFLAGS) $< -o $@

# EXE
%.o: $(PHIOLA)/src/exe/%.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/exe/*.h) \
		$(wildcard $(PHIOLA)/src/util/*.h)
	$(C) $(CFLAGS) $< -o $@

_:=
ifeq "$(OS)" "windows"
	EXE_COFF := exe.coff
endif
exe.coff: $(PHIOLA)/res/exe.rc \
		$(PHIOLA)/res/exe.manifest \
		$(PHIOLA)/res/phiola.ico
	$(WINDRES) $< $@

phiola$(DOTEXE): main.o \
		$(EXE_COFF) \
		core.$(SO)
	$(LINK) $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) $(LINK_DL) -o $@
EXES :=

# CORE
%.o: $(PHIOLA)/src/core/%.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/core/*.h) \
		$(wildcard $(PHIOLA)/src/util/*.h)
	$(C) $(CFLAGS) $< -o $@
%.o: $(PHIOLA)/src/queue/%.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/queue/*.h)
	$(C) $(CFLAGS) $< -o $@
CORE_O := core.o \
		auto.o \
		dir-read.o \
		file.o\
		qu.o \
		track.o
ifeq "$(OS)" "windows"
	CORE_O += sys-sleep-win.o
endif
core.$(SO): $(CORE_O)
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_PTHREAD) $(LINK_DL) -o $@

include $(PHIOLA)/src/adev/Makefile

# AFILTERS

MODS += afilter.$(SO)
%.o: $(PHIOLA)/src/afilter/%.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/afilter/*.h)
	$(C) $(CFLAGS) $< -o $@
crc.o: $(PHIOLA)/3pt/crc/crc.c
	$(C) $(CFLAGS) $< -o $@
afilter.$(SO): afilter.o \
		crc.o \
		peaks.o \
		gain.o \
		rtpeak.o \
		conv.o
	$(LINK) -shared $+ $(LINKFLAGS) -lm -o $@

MODS += soxr.$(SO)
LIBS3 += $(ALIB3_BIN)/libsoxr-phi.$(SO)
soxr.o: $(PHIOLA)/src/afilter/soxr.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/afilter/soxr*.h)
	$(C) $(CFLAGS) -I$(ALIB3) $< -o $@
soxr.$(SO): soxr.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(ALIB3_BIN) -lsoxr-phi -o $@

MODS += danorm.$(SO)
LIBS3 += $(ALIB3_BIN)/libDynamicAudioNormalizer-phi.$(SO)
dynanorm.o: $(PHIOLA)/src/afilter/dynanorm.c $(DEPS)
	$(C) $(CFLAGS) -I$(ALIB3) $< -o $@
danorm.$(SO): dynanorm.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(ALIB3_BIN) -lDynamicAudioNormalizer-phi -o $@

# FORMAT
MODS += format.$(SO)
%.o: $(PHIOLA)/src/format/%.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/format/*.h)
	$(C) $(CFLAGS) -I$(AVPACK) $< -o $@
cue-read.o: $(PHIOLA)/src/list/cue-read.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/list/entry.h)
	$(C) $(CFLAGS) -I$(AVPACK) $< -o $@
m3u.o: $(PHIOLA)/src/list/m3u.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/list/m3u-*.h) \
		$(wildcard $(PHIOLA)/src/list/entry.h)
	$(C) $(CFLAGS) -I$(AVPACK) $< -o $@
pls-read.o: $(PHIOLA)/src/list/pls-read.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/list/entry.h)
	$(C) $(CFLAGS) -I$(AVPACK) $< -o $@
format.$(SO): mod-fmt.o \
		aac-adts.o \
		ape-read.o \
		avi.o \
		caf.o \
		flac-fmt.o flac-ogg.o \
		mkv.o \
		mp3.o \
		mp4.o \
		mpc-read.o \
		ogg.o \
		wav.o \
		wv.o \
		\
		cue-read.o \
		m3u.o \
		pls-read.o
	$(LINK) -shared $+ $(LINKFLAGS) -o $@

ifneq "$(PHI_CODECS)" "0"

# CODECS LOSSY

MODS += aac.$(SO)
LIBS3 += $(ALIB3_BIN)/libfdk-aac-phi.$(SO)
aac.o: $(PHIOLA)/src/acodec/aac.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/acodec/aac-*.h) $(PHIOLA)/src/acodec/alib3-bridge/aac.h
	$(C) $(CFLAGS) -I$(ALIB3) $< -o $@
aac.$(SO): aac.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(ALIB3_BIN) -lfdk-aac-phi -o $@

MODS += mpeg.$(SO)
LIBS3 += $(ALIB3_BIN)/libmpg123-phi.$(SO)
mpeg.o: $(PHIOLA)/src/acodec/mpeg.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/acodec/mpeg-*.h)
	$(C) $(CFLAGS) -I$(ALIB3) $< -o $@
mpeg.$(SO): mpeg.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(ALIB3_BIN) -lmpg123-phi -o $@

MODS += vorbis.$(SO)
LIBS3 += $(ALIB3_BIN)/libvorbis-phi.$(SO) $(ALIB3_BIN)/libvorbisenc-phi.$(SO) $(ALIB3_BIN)/libogg-phi.$(SO)
vorbis.o: $(PHIOLA)/src/acodec/vorbis.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/acodec/vorbis-*.h) $(PHIOLA)/src/acodec/alib3-bridge/vorbis.h
	$(C) $(CFLAGS) -I$(ALIB3) -I$(AVPACK) $< -o $@
vorbis.$(SO): vorbis.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(ALIB3_BIN) -logg-phi -lvorbis-phi -lvorbisenc-phi -o $@

MODS += opus.$(SO)
LIBS3 += $(ALIB3_BIN)/libopus-phi.$(SO)
opus.o: $(PHIOLA)/src/acodec/opus.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/acodec/opus-*.h) $(PHIOLA)/src/acodec/alib3-bridge/opus.h
	$(C) $(CFLAGS) -I$(ALIB3) -I$(AVPACK) $< -o $@
opus.$(SO): opus.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(ALIB3_BIN) -lopus-phi -o $@

MODS += mpc.$(SO)
LIBS3 += $(ALIB3_BIN)/libmusepack-phi.$(SO)
mpc.o: $(PHIOLA)/src/acodec/mpc.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/acodec/mpc-*.h) $(PHIOLA)/src/acodec/alib3-bridge/musepack.h
	$(C) $(CFLAGS) -I$(ALIB3) $< -o $@
mpc.$(SO): mpc.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(ALIB3_BIN) -lmusepack-phi -o $@

# CODECS LOSSLESS

MODS += alac.$(SO)
LIBS3 += $(ALIB3_BIN)/libALAC-phi.$(SO)
alac.o: $(PHIOLA)/src/acodec/alac.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/acodec/alac-*.h) $(PHIOLA)/src/acodec/alib3-bridge/alac.h
	$(C) $(CFLAGS) -I$(ALIB3) $< -o $@
alac.$(SO): alac.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(ALIB3_BIN) -lALAC-phi -o $@

MODS += ape.$(SO)
LIBS3 += $(ALIB3_BIN)/libMAC-phi.$(SO)
ape.o: $(PHIOLA)/src/acodec/ape.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/acodec/ape-*.h) $(PHIOLA)/src/acodec/alib3-bridge/ape.h
	$(C) $(CFLAGS) -I$(ALIB3) -I$(AVPACK) $< -o $@
ape.$(SO): ape.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(ALIB3_BIN) -lMAC-phi -o $@

MODS += flac.$(SO)
LIBS3 += $(ALIB3_BIN)/libFLAC-phi.$(SO)
flac.o: $(PHIOLA)/src/acodec/flac.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/acodec/flac-*.h) $(PHIOLA)/src/acodec/alib3-bridge/flac.h
	$(C) $(CFLAGS) -I$(ALIB3) -I$(AVPACK) $< -o $@
flac.$(SO): flac.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(ALIB3_BIN) -lFLAC-phi -o $@

MODS += wavpack.$(SO)
LIBS3 += $(ALIB3_BIN)/libwavpack-phi.$(SO)
wavpack.o: $(PHIOLA)/src/acodec/wavpack.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/acodec/wavpack-*.h) $(PHIOLA)/src/acodec/alib3-bridge/wavpack.h
	$(C) $(CFLAGS) -I$(ALIB3) $< -o $@
wavpack.$(SO): wavpack.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(ALIB3_BIN) -lwavpack-phi -o $@

endif # PHI_CODECS

# MISC

ifeq "$(OS)" "linux"
MODS += dbus.$(SO)
sys-sleep-dbus.o: $(PHIOLA)/src/sys-sleep-dbus.c $(DEPS)
	$(C) $(CFLAGS) `pkg-config --cflags dbus-1` $< -o $@
dbus.$(SO): sys-sleep-dbus.o
	$(LINK) -shared $+ $(LINKFLAGS) -ldbus-1 -o $@
endif

MODS += remote.$(SO)
remote-ctl.o: $(PHIOLA)/src/remote-ctl.c $(DEPS)
	$(C) $(CFLAGS) $< -o $@
remote.$(SO): remote-ctl.o
	$(LINK) -shared $+ $(LINKFLAGS) -o $@

MODS += tui.$(SO)
%.o: $(PHIOLA)/src/tui/%.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/tui/*.h)
	$(C) $(CFLAGS) $< -o $@
tui.$(SO): tui.o
	$(LINK) -shared $+ $(LINKFLAGS) -lm -o $@

include $(PHIOLA)/src/gui/Makefile
include $(PHIOLA)/src/net/Makefile

MODS += zstd.$(SO)
LIBS3 += $(FFPACK_BIN)/libzstd-ffpack.$(SO)
%.o: $(PHIOLA)/src/dfilter/%.c $(DEPS) \
		$(wildcard $(PHIOLA)/src/dfilter/zstd-*.h)
	$(C) $(CFLAGS) -I$(FFPACK) $< -o $@
zstd.$(SO): zstd.o
	$(LINK) -shared $+ $(LINKFLAGS) $(LINK_RPATH_ORIGIN) -L$(FFPACK_BIN) -lzstd-ffpack -o $@


build: core.$(SO) \
		phiola$(DOTEXE) \
		$(EXES) \
		$(MODS)

strip-debug: core.$(SO).debug \
		phiola$(DOTEXE).debug \
		$(EXES:.exe=.exe.debug) \
		$(MODS:.$(SO)=.$(SO).debug)
%.debug: %
	$(OBJCOPY) --only-keep-debug $< $@
	$(STRIP) $<
	$(OBJCOPY) --add-gnu-debuglink=$@ $<
	touch $@

app:
	$(MKDIR) $(APP_DIR) $(APP_DIR)/mod
	$(CP) phiola$(DOTEXE) core.$(SO) \
		$(APP_DIR)/
	chmod 644 $(APP_DIR)/core.$(SO)
	$(CP) $(PHIOLA)/LICENSE \
		$(PHIOLA)/README.md \
		$(APP_DIR)/

	$(CP) $(MODS) $(APP_DIR)/mod/
ifneq "$(LIBS3)" ""
	$(CP) $(LIBS3) $(APP_DIR)/mod/
endif
	$(CP) $(PHIOLA)/src/tui/help.txt $(APP_DIR)/mod/tui-help.txt
	chmod 644 $(APP_DIR)/mod/*.$(SO)

	$(SUBMAKE) app-gui

ifeq "$(OS)" "windows"
	mv $(APP_DIR)/README.md $(APP_DIR)/README.txt
	unix2dos $(APP_DIR)/README.txt
endif

PKG_VER := test
PKG_ARCH := $(CPU)
PKG_PACKER := tar -c --owner=0 --group=0 --numeric-owner -v --zstd -f
PKG_EXT := tar.zst
ifeq "$(OS)" "windows"
	PKG_PACKER := zip -r -v
	PKG_EXT := zip
endif
PKG_NAME := phiola-$(PKG_VER)-$(OS)-$(PKG_ARCH).$(PKG_EXT)
package: $(PKG_NAME)
$(PKG_NAME): $(APP_DIR)
	$(PKG_PACKER) $@ $<
