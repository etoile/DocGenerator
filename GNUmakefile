include $(GNUSTEP_MAKEFILES)/common.make

CC = clang

TOOL_NAME = etdocgen

#
# Graphviz Support
#
# For version >= 2.30, libcgraph is stable and we use it. For these recent 
# versions, libgvc must link libcgraph, otherwise something is wrong in the host 
# sytem Graphviz packages.
#
# For version < 2.30, libcgraph is unstable or not available, and we use 
# libgraph.
# For these older versions, libgvc could link either just libgraph, or both 
# libgraph and libcgraph (but we just ignore libcgraph in this case, because it 
# tends to crash on some systems e.g. Ubuntu 12.04).
#
# For version < 2.23, libgraph is too old and is not supported. 
#
ifeq (`pkg-config --atleast-version=2.30`, 0)
  $(TOOL_NAME)_CPPFLAGS += -DWITH_CGRAPH=1 
endif

$(TOOL_NAME)_OBJCFLAGS += -fobjc-arc -Wparentheses `pkg-config libgvc --cflags`
# For Graphviz version >= 2.30, we expect pkg-config to return -lcgraph (never -lgraph)
# For example, Fedora could require a workaround, see https://bugzilla.redhat.com/show_bug.cgi?id=904790
$(TOOL_NAME)_TOOL_LIBS = -lEtoileFoundation -lSourceCodeKit `pkg-config libgvc --libs` 
 
# For SourceCodeKit dependencies
$(TOOL_NAME)_CPPFLAGS += -I`llvm-config --src-root`/tools/clang/include/ -I`llvm-config --includedir`
$(TOOL_NAME)_TOOL_LIBS += -lgnustep-gui
$(TOOL_NAME)_LDFLAGS += -L`llvm-config --libdir`

$(TOOL_NAME)_OBJC_FILES = $(wildcard *.m)

include $(GNUSTEP_MAKEFILES)/tool.make
-include ../../../etoile.make
-include ../../../documentation.make
