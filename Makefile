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
ISO		=	rbourgea_kfs.iso
CC		=	i686-elf-gcc
CFLAGS		=	-Wall -Wextra -ffreestanding -O2 -I./src #-I./klibft
LFLAGS		=	-nodefaultlibs -nostdlib
SRCS		=	src/kernel.c \
			# klibft/memset.c \
			# klibft/memcpy.c \
			# klibft/memcmp.c \
			# klibft/strlen.c \
			# klibft/putchar.c \
			# libk/printf.c
OBJS		=	$(SRCS:.c=.o)
ASM_SRCS	=	src/boot.s
ASM_OBJS	=	$(ASM_SRCS:.s=.o)

# **************************************************************************** #
# 📖 RULES
# **************************************************************************** #

all: $(NAME)

iso: $(NAME)
	@cp $(NAME) boot/
	@grub-mkrescue -o $(ISO) iso
	@echo "$(BOLD)$(CYAN)[✓] $(ISO) READY$(RESET)"

$(NAME): $(ASM_OBJS) $(OBJS) linker.ld
	@echo -n ' DONE'
	@echo "$(RESET)\n$(BOLD)$(GREEN)[✓] GENERATE OBJS DONE$(RESET)"
	@$(CC) -T linker.ld -o $@ $(CFLAGS) $(LFLAGS) $(ASM_OBJS) $(OBJS) -lgcc
	@echo "$(BOLD)$(GREEN)[✓] $(NAME) BUILD DONE$(RESET)"

# $(OBJS):
# 	@echo "$(BOLD)$(MAGENTA)"
# 	@clear
# 	@echo -n ' [☛] Building: '

# $(OBJS)%.o: $(SRCS)%.c
# 	@$(CC) $(FLAGS) $(INC) -o $@ -c $<
# 	@echo -n '#'

$(ASM_OBJS): $(ASM_SRCS)
	i686-elf-as $< -o $@

clean:
	@rm -rf $(ASM_OBJS) $(OBJS)
	@echo "$(BOLD)$(RED)[♻︎] DELETE OBJS DONE$(RESET)"

fclean: clean
	@rm -rf $(NAME)
	@rm -rf boot/$(NAME)
	@rm -rf $(ISO)
	@echo "$(BOLD)$(RED)[♻︎] DELETE BINARY FILES DONE$(RESET)"

re: fclean all

.PHONY: all clean fclean re iso