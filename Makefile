# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rbourgea <rbourgea@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2022/04/24 16:00:27 by rbourgea          #+#    #+#              #
#    Updated: 2022/06/16 19:07:01 by rbourgea         ###   ########.fr        #
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

KERNEL_OUT	=	build/rbourgea_kfs.bin
ISO_OUT		=	build/rbourgea_kfs.iso

BOOT		=	src/boot.s
KERNEL		=	src/kernel.c
LINKER		=	src/linker.ld

# **************************************************************************** #
# 📖 RULES
# **************************************************************************** #

all: build

build: fclean
	@mkdir -p build
	@nasm -f elf32 ${BOOT} -o build/boot.o
	@gcc -m32 -ffreestanding -c ${KERNEL} -o build/kernel.o
	@echo "$(BOLD)$(GREEN)[✓] KERNEL BUILD DONE$(RESET)"
	@ld -m elf_i386 -T ${LINKER} -o ${KERNEL_OUT} build/boot.o build/kernel.o
	@echo "$(BOLD)$(GREEN)[✓] KERNEL LINK DONE$(RESET)"

build_debug: fclean
	@echo "$(BOLD)$(YELLOW)[✓] KERNEL DEBUG MODE ON$(RESET)"
	@mkdir -p build
	@nasm -f elf32 ${BOOT} -o build/boot.o
	@gcc -m32 -ffreestanding -c ${KERNEL} -o build/kernel.o -ggdb
	@echo "$(BOLD)$(GREEN)[✓] KERNEL BUILD DONE$(RESET)"
	@ld -m elf_i386 -T ${LINKER} -o ${KERNEL_OUT} build/boot.o build/kernel.o
	@echo "$(BOLD)$(GREEN)[✓] KERNEL LINK DONE$(RESET)"

run: build
	@qemu-system-i386 -kernel ${KERNEL_OUT} -monitor stdio
	@echo "\n$(BOLD)$(CYAN)[✓] KERNEL EXIT DONE$(RESET)"

debug: build_debug
	@qemu-system-i386 -kernel ${KERNEL_OUT} -s -S &
	@gdb -x .gdbinit
	@echo "\n$(BOLD)$(CYAN)[✓] KERNEL DEBUG EXIT DONE$(RESET)"

iso: build
	@mkdir -p build/iso/boot/grub
	@cp grub.cfg build/iso/boot/grub
	@cp ${KERNEL_OUT} build/iso/boot/grub
	@grub-mkrescue -o ${ISO_OUT} build/iso
	@echo "$(BOLD)$(GREEN)[✓] KERNEL ISO BUILD$(RESET)"
	@rm -rf build/iso

run-iso: iso
	@qemu-system-i386 -cdrom ${ISO_OUT}
	@echo "\n$(BOLD)$(CYAN)[✓] KERNEL EXIT DONE$(RESET)"

clean:
	@rm -rf $(KERNEL_OUT) $(ISO_OUT)
	@echo "$(BOLD)$(RED)[♻︎] DELETE KERNEL DONE$(RESET)"

fclean:
	clear
	@rm -rf build/
	@echo "$(BOLD)$(RED)[♻︎] DELETE BUILD/ DONE$(RESET)"

re: fclean all

.PHONY: all clean fclean re