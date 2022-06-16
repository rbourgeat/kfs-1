# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rbourgea <rbourgea@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2022/04/24 16:00:27 by rbourgea          #+#    #+#              #
#    Updated: 2022/06/16 16:28:19 by rbourgea         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# **************************************************************************** #
# 🎨 COLORS
# **************************************************************************** #

GREY    	=	\033[030m
RED     	=	\033[031m
GREEN   	=	\033[032m
YELLOW  	=	\033[033m
BLUE    	=	\033[034m
MAGENTA 	=	\033[035m
CYAN		=	\033[036m
BOLD		=	\033[1m
RESET   	=	\033[0m

# **************************************************************************** #
# 💾 VARIABLES
# **************************************************************************** #

BOOT		=	src/boot.s
KERNEL		=	src/kernel.c
ISOFILE		=	build/rbourgea_kfs.iso
LINKER		=	src/linker.ld
KERNEL_OUT	=	build/rbourgea_kfs.bin
ISO_OUT		=	build/rbourgea_kfs.iso

# **************************************************************************** #
# 📖 RULES
# **************************************************************************** #

all: build

build: clean
	@mkdir -p build
	@nasm -f elf32 ${BOOT} -o build/boot.o
	@gcc -m32 -ffreestanding -c ${KERNEL} -o build/kernel.o
	@ld -m elf_i386 -T ${LINKER} -o ${KERNEL_OUT} build/boot.o build/kernel.o

build_debug: clean
	@mkdir -p build
	@nasm -f elf32 ${BOOT} -o build/boot.o
	@gcc -m32 -ffreestanding -c ${KERNEL} -o build/kernel.o -ggdb
	@ld -m elf_i386 -T ${LINKER} -o ${KERNEL_OUT} build/boot.o build/kernel.o

run: build
	@qemu-system-i386 -kernel ${KERNEL_OUT} -monitor stdio

debug: build_debug
	@qemu-system-i386 -kernel ${KERNEL_OUT} -s -S &
	@gdb -x .gdbinit

iso: build
	@mkdir -p build/iso/boot/grub
	@cp grub.cfg build/iso/boot/grub
	@cp ${KERNEL_OUT} build/iso/boot/grub
	@grub-mkrescue -o ${ISO_OUT} build/iso
	@rm -rf build/iso

run-iso: iso
	@qemu-system-i386 -cdrom ${ISOFILE}

# all: $(NAME)

# $(NAME): $(ASM_OBJS) $(OBJS) linker.ld
# 	@echo -n "$(RESET)\n$(BOLD)$(GREEN)[✓] GENERATE OBJS DONE$(RESET)"
# 	@$(CC) -T linker.ld -o $@ $(CFLAGS) $(LFLAGS) $(ASM_OBJS) $(OBJS) -lgcc
# 	@echo "$(BOLD)$(GREEN)[✓] $(NAME) LINK DONE$(RESET)"
# 	@cp $(NAME) boot/
# 	@grub-mkrescue -o $(ISO) . 2> /dev/null
# 	@echo "$(BOLD)$(GREEN)[✓] $(ISO) READY$(RESET)"

# debug:
# 	@qemu-system-i386 -cdrom rbourgea_kfs.iso -s -S -gdb stdio
# 	@gdb -x .gdbinit
# 	@echo "$(BOLD)$(CYAN)[✓] KERNEL DEBUG EXIT DONE$(RESET)"

# run:
# 	@qemu-system-i386 -cdrom rbourgea_kfs.iso
# 	@echo "$(BOLD)$(CYAN)[✓] KERNEL EXIT DONE$(RESET)"

# $(ASM_OBJS): $(ASM_SRCS)
# 	@clear
# 	nasm -f elf64 $< -o $@
# 	@echo "$(BOLD)$(GREEN)[✓] $(NAME) BUILD boot.s DONE$(RESET)"

# clean:
# 	@rm -rf $(ASM_OBJS) $(OBJS)
# 	@echo "$(BOLD)$(RED)[♻︎] DELETE OBJS DONE$(RESET)"

fclean: clean
	@echo "$(BOLD)$(RED)[♻︎] DELETE BINARY FILES DONE$(RESET)"

re: fclean all

.PHONY: all clean fclean re