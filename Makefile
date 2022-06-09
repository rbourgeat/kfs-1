# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rbourgea <rbourgea@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2022/04/24 16:00:27 by rbourgea          #+#    #+#              #
#    Updated: 2022/06/09 13:52:28 by rbourgea         ###   ########.fr        #
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

NAME		=	rbourgea_kernel
CC = i686-elf-gcc
CFLAGS = -Wall -Wextra -ffreestanding -O2 -I. -I./libk
LFLAGS = -nodefaultlibs -nostdlib
SRC_NAME = 
OBJS = $(SRCS:.c=.o)
SRC			=	$(addprefix $(SRC_PATH), $(SRC_NAME))
OBJ			=	$(addprefix $(OBJ_PATH), $(OBJ_NAME))

# **************************************************************************** #
# 📖 RULES
# **************************************************************************** #

all: $(NAME)

iso: $(NAME)
	@cp $(NAME) iso/boot/$(NAME)
	@grub-mkrescue -o kfs.iso iso
	@echo "$(BOLD)$(CYAN)[✓] $(NAME) READY$(RESET)"

$(NAME): $(OBJS) linker.ld boot.o
	@echo -n ' DONE'
	@echo "$(RESET)\n$(BOLD)$(GREEN)[✓] GENERATE OBJS DONE$(RESET)"
	@$(CC) -T linker.ld -o $@ $(CFLAGS) $(LFLAGS) boot.o $(OBJS) -lgcc
	@echo "$(BOLD)$(GREEN)[✓] $(NAME) BUILD DONE$(RESET)"

$(OBJ_PATH):
	@mkdir $(OBJ_PATH) 2> /dev/null || true
	@echo "$(BOLD)$(MAGENTA)"
	@clear
	@echo -n ' [☛] Building: '

$(OBJS)%.o: $(SRCS)%.c
	@$(CC) $(FLAGS) $(INC) -o $@ -c $<
	@echo -n '#'

boot.o: boot.s
	@i686-elf-as boot.s -o boot.o

clean:
	@rm -rf boot.o $(OBJS)
	@echo "$(BOLD)$(RED)[♻︎] DELETE OBJS DONE$(RESET)"

fclean: clean
	@$(RM) $(NAME)
	@$(RM) iso/boot/$(NAME)
	@$(RM) kfs.iso
	@echo "$(BOLD)$(RED)[♻︎] DELETE BINARY FILES DONE$(RESET)"

re: fclean all

$(ASM_SRC_NAME)%.o: $(ASM_OBJ_NAME)%.s
	@$(ASM) -o $@ -s $<
	@echo "compiling boot.s"

.PHONY: all clean fclean re iso