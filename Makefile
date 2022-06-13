# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rbourgea <rbourgea@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2022/04/24 16:00:27 by rbourgea          #+#    #+#              #
#    Updated: 2022/06/10 15:22:37 by rbourgea         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# **************************************************************************** #
# 🎨 COLORS
# **************************************************************************** #

GREY    	=	\033[030m
RED     	=	\033[031m # Error or Clean
GREEN   	=	\033[032m # Done
YELLOW  	=	\033[033m # Info
BLUE    	=	\033[034m
MAGENTA 	=	\033[035m # Build or Loading
CYAN		=	\033[036m # End
BOLD		=	\033[1m
RESET   	=	\033[0m

# **************************************************************************** #
# 💾 VARIABLES
# **************************************************************************** #

NAME		=	rbourgea_kfs.bin
ISO			=	rbourgea_kfs.iso

CPATH		=	/home/user42/Bureau/i386-elf-7.5.0-Linux-x86_64/bin/
CC			=	$(CPATH)i386-elf-gcc
CFLAGS		=	-Wall -Wextra -ffreestanding -O2 -I./src
LFLAGS		=	-nodefaultlibs -nostdlib

SRCS		=	src/kernel.c
OBJS		=	$(SRCS:.c=.o)
ASM_SRCS	=	src/boot.s
ASM_OBJS	=	$(ASM_SRCS:.s=.o)

# **************************************************************************** #
# 📖 RULES
# **************************************************************************** #

all: $(NAME)

$(NAME): $(ASM_OBJS) $(OBJS) linker.ld
	@echo -n ' DONE'
	@echo "$(RESET)\n$(BOLD)$(GREEN)[✓] GENERATE OBJS DONE$(RESET)"
	@$(CC) -T linker.ld -o $@ $(CFLAGS) $(LFLAGS) $(ASM_OBJS) $(OBJS) -lgcc
	@echo "$(BOLD)$(GREEN)[✓] $(NAME) BUILD DONE$(RESET)"
	@cp $(NAME) boot/
	@grub-mkrescue -o $(ISO) .
	@echo "$(BOLD)$(GREEN)[✓] $(ISO) READY$(RESET)"
	@qemu-system-i386 -cdrom rbourgea_kfs.iso
	@echo "$(BOLD)$(CYAN)[✓] BOOT DONE$(RESET)"

# $(OBJS):
# 	@echo "$(BOLD)$(MAGENTA)"
# 	@clear
# 	@echo -n ' [☛] Building: '

# $(OBJS)%.o: $(SRCS)%.c
# 	@$(CC) $(FLAGS) $(INC) -o $@ -c $<
# 	@echo -n '#'

$(ASM_OBJS): $(ASM_SRCS)
	$(CPATH)i386-elf-as $< -o $@

clean:
	@rm -rf $(ASM_OBJS) $(OBJS)
	@echo "$(BOLD)$(RED)[♻︎] DELETE OBJS DONE$(RESET)"

fclean: clean
	@rm -rf $(NAME)
	@rm -rf boot/$(NAME)
	@rm -rf $(ISO)
	@echo "$(BOLD)$(RED)[♻︎] DELETE BINARY FILES DONE$(RESET)"

re: fclean all

.PHONY: all clean fclean re