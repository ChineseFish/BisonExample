FLEX=flex
FLEXFLAGS=
BISON=bison
BISONFLAGS=-t --report=itemset -o 
CC=gcc
CFLAGS=-g -Wall -lm

#
SUB_DIRS=calc

#记住当前工程的根目录路径
ROOT_DIR=$(shell pwd)

#目标文件所在的目录
OBJS_DIR=$(ROOT_DIR)/obj

#获取c
CUR_SOURCE=${wildcard *.c}

#
CUR_OBJS=${patsubst %.c, $(OBJS_DIR)/%.o, $(notdir $(CUR_SOURCE))}

#
export OBJS_DIR CC CFLAGS

all:$(SUB_DIRS) $(CUR_OBJS) DEBUG 

#递归执行子目录下的makefile文件
$(SUB_DIRS):ECHO
	make -C $@

DEBUG:ECHO
	make -C debug

ECHO:
	@echo $(SUBDIRS)

$(OBJS_DIR)/%.o:%.c
	$(CC) $(CFLAGS) -o $@ -c $<

pre:
	$(BISON) $(BISONFLAGS) calc/parser.c calc/parser.y
	$(FLEX) $(FLEXFLAGS) calc/scanner.l

clean:
	rm -f debug/mfcalc
	rm -f $(OBJS_DIR)/*.o
	rm -f calc/parser.output

cleanall:clean
	rm -f calc/parser.h calc/parser.c