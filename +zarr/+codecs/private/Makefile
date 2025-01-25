# Compiler settings
MEX = mex
ZSTD_DIR = ../../../numcodecs/c-blosc/internal-complibs/zstd-1.5.6
CFLAGS = -O3 -I$(ZSTD_DIR) -DXXH_NAMESPACE=ZSTD_ -DZSTD_LEGACY_SUPPORT=0

# Source files
ZSTD_COMMON = $(ZSTD_DIR)/common/debug.c \
              $(ZSTD_DIR)/common/entropy_common.c \
              $(ZSTD_DIR)/common/error_private.c \
              $(ZSTD_DIR)/common/fse_decompress.c \
              $(ZSTD_DIR)/common/pool.c \
              $(ZSTD_DIR)/common/threading.c \
              $(ZSTD_DIR)/common/xxhash.c \
              $(ZSTD_DIR)/common/zstd_common.c

ZSTD_COMPRESS = $(ZSTD_DIR)/compress/fse_compress.c \
                $(ZSTD_DIR)/compress/hist.c \
                $(ZSTD_DIR)/compress/huf_compress.c \
                $(ZSTD_DIR)/compress/zstd_compress.c \
                $(ZSTD_DIR)/compress/zstd_compress_literals.c \
                $(ZSTD_DIR)/compress/zstd_compress_sequences.c \
                $(ZSTD_DIR)/compress/zstd_compress_superblock.c \
                $(ZSTD_DIR)/compress/zstd_double_fast.c \
                $(ZSTD_DIR)/compress/zstd_fast.c \
                $(ZSTD_DIR)/compress/zstd_lazy.c \
                $(ZSTD_DIR)/compress/zstd_ldm.c \
                $(ZSTD_DIR)/compress/zstd_opt.c

ZSTD_DECOMPRESS = $(ZSTD_DIR)/decompress/huf_decompress.c \
                  $(ZSTD_DIR)/decompress/zstd_ddict.c \
                  $(ZSTD_DIR)/decompress/zstd_decompress.c \
                  $(ZSTD_DIR)/decompress/zstd_decompress_block.c

ZSTD_SRCS = $(ZSTD_COMMON) $(ZSTD_COMPRESS) $(ZSTD_DECOMPRESS)

# Targets
all: zstdmex zstddmex

zstdmex: zstdmex.c
	$(MEX) COMPFLAGS="$(CFLAGS)" $< $(ZSTD_SRCS) -output $@

zstddmex: zstddmex.c
	$(MEX) COMPFLAGS="$(CFLAGS)" $< $(ZSTD_SRCS) -output $@

clean:
	rm -f *.o *.mex*
