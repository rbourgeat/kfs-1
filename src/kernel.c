/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   kernel.c                                           :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: rbourgea <rbourgea@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2022/06/16 16:29:20 by rbourgea          #+#    #+#             */
/*   Updated: 2022/06/17 07:18:03 by rbourgea         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

/* ************************************************************************** */
/* Includes                                                                   */
/* ************************************************************************** */

#include "keyboard_map.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* ************************************************************************** */
/* Pre-processor constants                                                    */
/* ************************************************************************** */

# define LINES 25 // 2 bytes each
# define COLUMNS_IN_LINE 80

# define IDT_SIZE 256 // Specific to x86 architecture
# define KERNEL_CODE_SEGMENT_OFFSET 0x8
# define IDT_INTERRUPT_GATE_32BIT 0x8e

# define PIC1_COMMAND_PORT 0x20
# define PIC1_DATA_PORT 0x21
# define PIC2_COMMAND_PORT 0xA0
# define PIC2_DATA_PORT 0xA1

# define KEYBOARD_DATA_PORT 0x60
# define KEYBOARD_STATUS_PORT 0x64

/* ************************************************************************** */
/* boots.s functions                                                          */
/* ************************************************************************** */

extern void print_char_with_asm(char c, int row, int col);
extern void keyboard_handler();
extern char ioport_in(unsigned short port);
extern void ioport_out(unsigned short port, unsigned char data);
extern void load_idt(unsigned int* idt_address);
extern void enable_interrupts();

/* ************************************************************************** */
/* Structs                                                                    */
/* ************************************************************************** */

struct IDT_pointer {
	unsigned short limit;
	unsigned int base;
} __attribute__((packed));

struct IDT_entry {
	unsigned short offset_lowerbits; // 16 bits
	unsigned short selector; // 16 bits
	unsigned char zero; // 8 bits
	unsigned char type_attr; // 8 bits
	unsigned short offset_upperbits; // 16 bits
} __attribute__((packed));

enum vga_color {
	VGA_COLOR_BLACK = 0,
	VGA_COLOR_BLUE = 1,
	VGA_COLOR_GREEN = 2,
	VGA_COLOR_CYAN = 3,
	VGA_COLOR_RED = 4,
	VGA_COLOR_MAGENTA = 5,
	VGA_COLOR_BROWN = 6,
	VGA_COLOR_LIGHT_GREY = 7,
	VGA_COLOR_DARK_GREY = 8,
	VGA_COLOR_LIGHT_BLUE = 9,
	VGA_COLOR_LIGHT_GREEN = 10,
	VGA_COLOR_LIGHT_CYAN = 11,
	VGA_COLOR_LIGHT_RED = 12,
	VGA_COLOR_LIGHT_MAGENTA = 13,
	VGA_COLOR_LIGHT_BROWN = 14,
	VGA_COLOR_WHITE = 15,
};

// struct s_screen {
// 	unsigned int nb;
// 	uint16_t	*terminal_buffer;
// }		t_screen;

/* ************************************************************************** */
/* Globals                                                                    */
/* ************************************************************************** */

uint16_t ttys[10];

struct IDT_entry IDT[IDT_SIZE]; // This is our entire IDT. Room for 256 interrupts

static const size_t VGA_WIDTH = 80;
static const size_t VGA_HEIGHT = 25;
 
size_t		tty_row;
size_t		tty_column;
uint8_t		tty_color;
uint16_t	*terminal_buffer;

char*		prompt_buffer;
int			tty_nb = 0;

/* ************************************************************************** */
/* Functions                                                                  */
/* ************************************************************************** */

void	kputstr(const char* data);
void	kputchar(char c);
size_t	kstrlen(const char* str);
void	kcolor(uint8_t color);
void	kprompt(char c);
char	*kstrjoin(char const *s1, char const *s2);
char	*kitoa(int n);
void	terminal_initialize(int init);
static void khello(void);

void init_idt()
{
	unsigned int offset = (unsigned int)keyboard_handler; //get addr in boot.s
	// Populate the first entry of the IDT
	// TODO why 0x21 and not 0x0?
	// My guess: 0x0 to 0x2 are reserved for CPU, so we use the first avail
	IDT[0x21].offset_lowerbits = offset & 0x0000FFFF; // lower 16 bits
	IDT[0x21].selector = KERNEL_CODE_SEGMENT_OFFSET;
	IDT[0x21].zero = 0;
	IDT[0x21].type_attr = IDT_INTERRUPT_GATE_32BIT;
	IDT[0x21].offset_upperbits = (offset & 0xFFFF0000) >> 16;
	// Program the PICs - Programmable Interrupt Controllers
	// Background:
		// In modern architectures, the PIC is not a separate chip.
		// It is emulated in the CPU for backwards compatability.
		// The APIC (Advanced Programmable Interrupt Controller)
		// is the new version of the PIC that is integrated into the CPU.
		// Default vector offset for PIC is 8
		// This maps IRQ0 to interrupt 8, IRQ1 to interrupt 9, etc.
		// This is a problem. The CPU reserves the first 32 interrupts for
		// CPU exceptions such as divide by 0, etc.
		// In programming the PICs, we move this offset to 0x2 (32) so that
		// we can handle all interrupts coming to the PICs without overlapping
		// with any CPU exceptions.

	// Send ICWs - Initialization Command Words
	// PIC1: IO Port 0x20 (command), 0xA0 (data)
	// PIC2: IO Port 0x21 (command), 0xA1 (data)
	// ICW1: Initialization command
	// Send a fixed value of 0x11 to each PIC to tell it to expect ICW2-4
	// Restart PIC1
	ioport_out(PIC1_COMMAND_PORT, 0x11);
	ioport_out(PIC2_COMMAND_PORT, 0x11);
	// ICW2: Vector Offset (this is what we are fixing)
	// Start PIC1 at 32 (0x20 in hex) (IRQ0=0x20, ..., IRQ7=0x27)
	// Start PIC2 right after, at 40 (0x28 in hex)
	ioport_out(PIC1_DATA_PORT, 0x20);
	ioport_out(PIC2_DATA_PORT, 0x28);
	// ICW3: Cascading (how master/slave PICs are wired/daisy chained)
	// Tell PIC1 there is a slave PIC at IRQ2 (why 4? don't ask me - https://wiki.osdev.org/8259_PIC)
	// Tell PIC2 "its cascade identity" - again, I'm shaky on this concept. More resources in notes
	ioport_out(PIC1_DATA_PORT, 0x0);
	ioport_out(PIC2_DATA_PORT, 0x0);
	// ICW4: "Gives additional information about the environemnt"
	// See notes for some potential values
	// We are using 8086/8088 (MCS-80/85) mode
	// Not sure if that's relevant, but there it is.
	// Other modes appear to be special slave/master configurations (see wiki)
	ioport_out(PIC1_DATA_PORT, 0x1);
	ioport_out(PIC2_DATA_PORT, 0x1);
	// Voila! PICs are initialized

	// Mask all interrupts (why? not entirely sure)
	// 0xff is 16 bits that are all 1.
	// This masks each of the 16 interrupts for that PIC.
	ioport_out(PIC1_DATA_PORT, 0xff);
	ioport_out(PIC2_DATA_PORT, 0xff);

	// Last but not least, we fill out the IDT descriptor
	// and load it into the IDTR register of the CPU,
	// which is all we need to do to make it active.
	struct IDT_pointer idt_ptr;
	idt_ptr.limit = (sizeof(struct IDT_entry) * IDT_SIZE) - 1;
	idt_ptr.base = (unsigned int) &IDT;
	// Now load this IDT
	load_idt((unsigned int*)&idt_ptr);
}

void kb_init()
{
	// 0xFD = 1111 1101 in binary. enables only IRQ1
	// Why IRQ1? Remember, IRQ0 exists, it's 0-based
	ioport_out(PIC1_DATA_PORT, 0xFD);
}

void handle_keyboard_interrupt()
{
	ioport_out(PIC1_COMMAND_PORT, 0x20); // write end of interrupt (EOI)
	unsigned char status = ioport_in(KEYBOARD_STATUS_PORT);

	if (status & 0x1) {
		char keycode = ioport_in(KEYBOARD_DATA_PORT);
		if (keycode < 0 || keycode >= 128)
			return;
		kprompt(keyboard_map[keycode]);
	}
}

char	*kstrjoin(char const *s1, char const *s2)
{
	size_t	count;
	size_t	size_s1;
	char	*tab;

	count = -1;
	if (!s1 || !s2)
		return (NULL);
	size_s1 = kstrlen(s1);
	while (s1[++count])
		tab[count] = s1[count];
	count = -1;
	while (s2[++count])
		tab[size_s1 + count] = s2[count];
	tab[size_s1 + count] = '\0';
	return (tab);
}

void switch_screen(int nb)
{
	// ttys[tty_nb] = terminal_buffer;
	// prompt_buffer = "";
	if (ttys[nb])
	{
		// terminal_buffer = ttys[nb];
		tty_nb = nb;
		terminal_initialize(1);
		khello();
		kprompt(0);
	}
	else
	{
		tty_nb = nb;
		terminal_initialize(1);
		khello();
		kprompt(0);
	}
}

void kprompt(char c)
{
	char *tmp;

	tmp[0] = c;
	if (c == '\n')			// Enter
		kputchar('\n');
	else if (c == '\b')		// Delete
	{
		if (tty_column == 0)
			return;
		tty_column--;
		kputchar(' ');
		tty_column--;
		return;
	}
	else if (c == -11)		// left Ctrl
	{
		// kputstr("left Ctrl");
		return;
	}
	else if (c == -12)		// left Shift
	{
		// kputstr("left Shift");
		return;
	}
	else if (c < 0 && c > -11)	// F1 to F10
	{
		switch_screen(c + (-c * 2) - 1); // shortcut
		return;
	}
	if (tty_column == 0)
	{
		kcolor(VGA_COLOR_RED);
		kputstr("[@rbourgea] \7 ");
		kcolor(VGA_COLOR_LIGHT_GREY);
	}
	if (c != '\n')
		kputchar((const char)c);
}

static inline uint8_t vga_entry_color(enum vga_color fg, enum vga_color bg)
{
	return fg | bg << 4;
}

static inline uint16_t vga_entry(unsigned char uc, uint8_t color)
{
	return (uint16_t) uc | (uint16_t) color << 8;
}
 
size_t kstrlen(const char* str)
{
	size_t len = 0;
	while (str[len])
		len++;
	return len;
}

void terminal_initialize(int init)
{
	tty_row = 0;
	tty_column = 0;
	tty_color = vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
	if (init == 1)
		terminal_buffer = (uint16_t*) 0xB8000;
	for (size_t y = 0; y < VGA_HEIGHT; y++) {
		for (size_t x = 0; x < VGA_WIDTH; x++) {
			const size_t index = y * VGA_WIDTH + x;
			if (init == 1)
				terminal_buffer[index] = vga_entry(' ', tty_color);
			else
				vga_entry(terminal_buffer[index], tty_color);
		}
	}
}

void kcolor(uint8_t color)
{
	tty_color = color;
}
 
void terminal_putentryat(char c, uint8_t color, size_t x, size_t y) 
{
	const size_t index = y * VGA_WIDTH + x;
	terminal_buffer[index] = vga_entry(c, color);
}

static int count_digits(int n)
{
	int digits;

	if (n == 0)
		return (1);
	digits = n < 0 ? 1 : 0;
	while (n != 0)
	{
		n = n / 10;
		digits++;
	}
	return (digits);
}

char *kitoa(int n)
{
	char			*result;
	int				digits;
	int				i;
	int				stop;
	unsigned	int	nbr;

	digits = count_digits(n);
	i = digits - 1;
	stop = ((n < 0) ? 0 : -1);
	if (n < 0)
		nbr = n == -2147483648 ? 2147483648 : -n;
	else
		nbr = n;
	result[digits] = '\0';
	while (i > stop)
	{
		result[i--] = nbr % 10 + '0';
		nbr = nbr / 10;
	}
	if (stop == 0)
		result[0] = '-';
	return (result);
}

void kputchar(char c)
{
	if (c == '\n') {
		tty_column = 0;
		tty_row++;
		return;
	}
	terminal_putentryat(c, tty_color, tty_column, tty_row);
	if (++tty_column == VGA_WIDTH) {
		tty_column = 0;
		if (++tty_row == VGA_HEIGHT)
			tty_row = 0;
	}
}

void kputstr(const char* data) 
{
	for (size_t i = 0; i < kstrlen(data); i++)
		kputchar(data[i]);
}

static void khello(void)
{
	kcolor(VGA_COLOR_LIGHT_GREEN);
	kputstr("\n $$\\   $$\\  $$$$$$\\        $$\\        $$$$$$\\           \n");
	kputstr(" $$ |  $$ |$$  __$$\\       $$ |      $$  __$$\\          \n");
	kputstr(" $$ |  $$ |\\__/  $$ |      $$ |  $$\\ $$ /  \\__|$$$$$$$\\ \n");
	kputstr(" $$$$$$$$ | $$$$$$  |      $$ | $$  |$$$$\\    $$  _____|\n");
	kputstr(" \\_____$$ |$$  ____/       $$$$$$  / $$  _|   \\$$$$$$\\  \n");
	kputstr("       $$ |$$ |            $$  _$$<  $$ |      \\____$$\\ \n");
	kputstr("       $$ |$$$$$$$$\\       $$ | \\$$\\ $$ |     $$$$$$$  |\n");
	kputstr("       \\__|\\________|      \\__|  \\__|\\__|     \\_______/ \n\n");
	kputstr("                                           by rbourgea \2\n");
	kcolor(VGA_COLOR_LIGHT_MAGENTA);
	kputstr("\4 Login on ttys");
	kputchar((char)(tty_nb + '0'));
	kputstr("\n\n");
	kcolor(VGA_COLOR_WHITE);
}

void kmain()
{
	terminal_initialize(1);
	khello();
	kputstr("\11 Hello, 42!\n\n");

	init_idt();
	kb_init();
	enable_interrupts();

	kprompt(0);
	while(42);
}
