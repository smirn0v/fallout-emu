/*
	pev - the PE file analyzer toolkit
	
	pedis.c - PE disassembler

	Copyright (C) 2012 pev authors

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "common.h"
#include "../lib/libudis86/udis86.h"
#include <errno.h>
#include <limits.h>

#define PROGRAM "pedis"

#define SYN_ATT 1
#define SYN_INTEL 0

typedef struct {
	bool all_sections;
	char *section;
	bool syntax;
	uint64_t offset;
	uint64_t nbytes;           // limit the number of bytes instructions. 0 means no limit.
	uint64_t ninstructions;     // limit the number of disassembled instructions. 0 means no limit.
	bool entrypoint;
	bool offset_is_rva;
	uint16_t mode;
} options_t;

static void usage(void)
{
	printf("Usage: %s OPTIONS FILE\n"
		"Disassemble PE sections and functions (by default, until found a RET or LEAVE instruction)\n"
		"\nExample: %s -r 0x4c4df putty.exe\n"
		"\nOptions:\n"
		" --att                                  set AT&T syntax\n"
		" -e, --entrypoint                       disassemble entrypoint\n"
		" -f, --format <text|csv|xml|html>       change output format (default: text)\n"
		" -m, --mode <16|32|64>                  disassembly mode (default: auto)\n"
		" -i, <number>                           number of instructions to be disassembled\n"
		" -n, <number>                           number of bytes to be disassembled\n"
		" -o, --offset <offset>                  disassemble at specified file offset\n"
		" -r, --rva <rva>                        disassemble at specified RVA\n"
		" -s, --section <section_name>           disassemble entire section given\n"
		" -v, --version                          show version and exit\n"
		" --help                                 show this help and exit\n",
		PROGRAM, PROGRAM);
}

static void free_options(options_t *options)
{
	if (options == NULL)
		return;

	if (options->section != NULL)
		free(options->section);

	free(options);
}

static options_t *parse_options(int argc, char *argv[])
{
	options_t *options = malloc_s(sizeof(options_t));
	memset(options, 0, sizeof(options_t));

	/* Parameters for getopt_long() function */
	static const char short_options[] = "em:i:n:o:r:s:f:v";

	static const struct option long_options[] = {
		{ "help",             no_argument,       NULL,  1  },
		{ "att",              no_argument,       NULL,  2  },
		{ "",                 required_argument, NULL, 'n' },
		{ "entrypoint",       no_argument,       NULL, 'e' },
		{ "mode",             required_argument, NULL, 'm' },
		{ "offset",           required_argument, NULL, 'o' },
		{ "rva",              required_argument, NULL, 'r' },
		{ "section",          required_argument, NULL, 's' },
		{ "format",           required_argument, NULL, 'f' },
		{ "version",          no_argument,       NULL, 'v' },
		{ NULL,               0,                 NULL,  0  }
	};

	options->syntax = SYN_INTEL;

	int c, ind;

	while ((c = getopt_long(argc, argv, short_options, long_options, &ind)))
	{
		if (c < 0)
			break;

		switch (c)
		{
			case 1:		// --help option
				usage();
				exit(EXIT_SUCCESS);
			case 2:
				options->syntax = SYN_ATT;
				break;
			case 'e':
				options->entrypoint = true;
				break;
			case 'm':
				options->mode = strtol(optarg, NULL, 10);
				switch (options->mode) {
					default: EXIT_ERROR("Bad argument for mode.");
					case 16: break;
					case 32: break;
					case 64: break;
				}
				break;
			case 'i':
				options->ninstructions = strtol(optarg, NULL, 0);
				if (errno == ERANGE)
					EXIT_ERROR("number of instructions value would underflow or overflow");
				break;
			case 'n':
				options->nbytes = strtol(optarg, NULL, 0);
				if (errno == ERANGE)
					EXIT_ERROR("number of bytes value would underflow or overflow");
				break;
			case 'o':
				options->offset = strtol(optarg, NULL, 0);
				if (errno == ERANGE)
					EXIT_ERROR("offset value would underflow or overflow");
				options->offset_is_rva = false;
				break;
			case 'r':
				options->offset = strtol(optarg, NULL, 0);
				if (errno == ERANGE)
					EXIT_ERROR("rva value would underflow or overflow");
				options->offset_is_rva = true;
				break;
			case 's':
				options->section = strdup(optarg);
				break;
			case 'v':
				printf("%s %s\n%s\n", PROGRAM, TOOLKIT, COPY);
				exit(EXIT_SUCCESS);
			case 'f':
				parse_format(optarg);
				break;
			default:
				fprintf(stderr, "%s: try '--help' for more information\n", PROGRAM);
				exit(EXIT_FAILURE);
		}
	}

	return options;
}

static char *insert_spaces(const char *s) 
{
	size_t size;
	char *new; 

	size = strlen(s);

	if (!size)
		return NULL;

	size = size + (size/2);

	new = malloc_s(size+1);
	memset(new, 0, size+1);

	for (unsigned int i=0, j=0, pos=0; i < size; i++)
	{   
		if (pos==2)
		{   
			new[i] = ' ';
			pos=0;
		}   
		else
		{   
			new[i] = s[j++];
			pos++;
		}   
	}   
	return new;
}

static bool is_ret_instruction(unsigned char opcode)
{
	switch (opcode)
	{
		case 0xc9: // leave
		//case 0xc2: // ret
		case 0xc3: // ret
		case 0xca: // retf
		//case 0xcb: // retf
			return true;
		
		default:
			return false;
	}
}

static void disassemble_offset(pe_ctx_t *ctx, const options_t *options, ud_t *ud_obj, uint64_t offset)
{
	if (ctx == NULL || offset == 0)
		return;

	uint64_t c = 0; // counter for disassembled instructions
	uint64_t b = 0; // counter for disassembled bytes

	while (ud_disassemble(ud_obj))
	{
		char ofs[MAX_MSG], value[MAX_MSG], *bytes;
		unsigned char *opcode = ud_insn_ptr(ud_obj);
		unsigned int mnic, op_t;

		c++; // increment instruction counter
		b += ud_insn_len(ud_obj);

		if (options->nbytes && b >= options->nbytes)
			return;

		mnic = ud_obj->mnemonic;
		op_t = ud_obj->operand ? ud_obj->operand[0].type : 0;
		
		snprintf(ofs, MAX_MSG, "%"PRIx64, (options->offset_is_rva ? ctx->pe.imagebase : 0) + offset + ud_insn_off(ud_obj));
		bytes = insert_spaces(ud_insn_hex(ud_obj));

		if (!bytes)
			return;

		// correct near operand addresses for calls and jumps
		if (op_t && (op_t != UD_OP_MEM) && (mnic == UD_Icall || (mnic >= UD_Ijo && mnic <= UD_Ijmp)))
		{
			char *ins = strtok(ud_insn_asm(ud_obj), "0x");

			snprintf(value,
				MAX_MSG,
				"%s%*c%s%#"PRIx64,
				bytes,
				SPACES - (int) strlen(bytes),
				' ',
				ins ? ins : "",
				ctx->pe.imagebase + offset + ud_insn_off(ud_obj) + ud_obj->operand[0].lval.sdword + ud_insn_len(ud_obj)
			);
		}
		else
			snprintf(value, MAX_MSG, "%s%*c%s", bytes, SPACES - (int) strlen(bytes), ' ', ud_insn_asm(ud_obj));

		free(bytes);
		output(ofs, value);

		// for sections, we stop at end of section
		if (options->section && c >= options->ninstructions)
			break;
		else if (c >= options->ninstructions && options->ninstructions)
			break;
		else if (options->entrypoint)
		{
		// search for LEAVE or RET insrtuctions
		for (unsigned int i=0; i < ud_insn_len(ud_obj); i++)
			if (is_ret_instruction(opcode[i]))
				return;
		}
	}
}

int main(int argc, char *argv[])
{
	if (argc < 2) {
		usage();
		exit(EXIT_FAILURE);
	}

	options_t *options = parse_options(argc, argv); // opcoes

	const char *path = argv[argc-1];
	pe_ctx_t ctx;

	pe_err_e err = pe_load_file_ext(&ctx, path, LIBPE_OPT_NOCLOSE_FD);
	if (err != LIBPE_E_OK) {
		pe_error_print(stderr, err);
		return EXIT_FAILURE;
	}

	err = pe_parse(&ctx);
	if (err != LIBPE_E_OK) {
		pe_error_print(stderr, err);
		return EXIT_FAILURE;
	}

	if (!pe_is_pe(&ctx))
		EXIT_ERROR("not a valid PE file");

	IMAGE_OPTIONAL_HEADER *optional = pe_optional(&ctx);
	if (optional == NULL)
		return EXIT_FAILURE;

	ud_t ud_obj; // libudis86 object
	ud_init(&ud_obj);
	
	uint8_t mode_bits = 0;
	switch (optional->type) {
		default:
			EXIT_ERROR("Unsupported architecture.");
			return EXIT_FAILURE;
		case MAGIC_PE32: mode_bits = 32; break;
		case MAGIC_PE64: mode_bits = 64; break;
	}

	// set disassembly mode according with PE architecture
	ud_set_mode(&ud_obj, options->mode ? options->mode : mode_bits);

	uint64_t offset = 0;         // offset to start disassembly

	if (options->entrypoint)
		offset = pe_rva2ofs(&ctx, ctx.pe.entrypoint);
	else if (options->offset)
		offset = options->offset_is_rva ? pe_rva2ofs(&ctx, options->offset) : options->offset;
	else if (options->section) {
		IMAGE_SECTION_HEADER *section = pe_section_by_name(&ctx, options->section);

		if (section) { // section found
			offset = section->PointerToRawData;
			if (!options->ninstructions)
				options->ninstructions = section->SizeOfRawData;
		}
		else
			EXIT_ERROR("invalid section name");
	} else {
		usage();
		return EXIT_FAILURE;
	}
	
	if (!offset) {
		fprintf(stderr, "unable to reach file offset (%#"PRIx64")\n", offset);
		return EXIT_FAILURE;
	}

	ud_set_syntax(&ud_obj, options->syntax ? UD_SYN_ATT : UD_SYN_INTEL);
	ud_set_input_buffer(&ud_obj, ctx.map_addr, pe_filesize(&ctx));
	//ud_set_input_file(&ud_obj, ctx.stream);
	ud_input_skip(&ud_obj, offset);
	disassemble_offset(&ctx, options, &ud_obj, offset);

	// libera a memoria
	free_options(options);

	// free
	err = pe_unload(&ctx);
	if (err != LIBPE_E_OK) {
		pe_error_print(stderr, err);
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}
