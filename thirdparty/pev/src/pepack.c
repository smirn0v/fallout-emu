/*
	pev - the PE file analyzer toolkit
	
	pepack.c - search packers in PE files

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

#define PROGRAM "pepack"
#define MAX_SIG_SIZE 2048

typedef struct {
	char *dbfile;
} options_t;

static void usage(void)
{
	printf("Usage: %s FILE\n"
		"Search for packers in PE files\n"
		"\nExample: %s putty.exe\n"
		"\nOptions:\n"
		" -d, --database <file>                  use database file (default: ./userdb.txt)\n"
		" -f, --format <text|csv|xml|html>       change output format (default: text)\n"
		" -v, --version                          show version and exit\n"
		" --help                                 show this help and exit\n",
		PROGRAM, PROGRAM);
}

static void free_options(options_t *options)
{
	if (options == NULL)
		return;

	if (options->dbfile != NULL)
		free(options->dbfile);

	free(options);
}

static options_t *parse_options(int argc, char *argv[])
{
	options_t *options = malloc_s(sizeof(options_t));
	memset(options, 0, sizeof(options_t));

	/* Parameters for getopt_long() function */
	static const char short_options[] = "d:f:v";

	static const struct option long_options[] = {
		{ "database",         required_argument, NULL, 'd' },
		{ "format",           required_argument, NULL, 'f' },
		{ "help",             no_argument,       NULL,  1  },
		{ "version",          no_argument,       NULL, 'v' },
		{ NULL,               0,                 NULL,  0  }
	};

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
			case 'd':
				options->dbfile = strdup(optarg);
				break;
			case 'f':
				parse_format(optarg); break;
			case 'v':
				printf("%s %s\n%s\n", PROGRAM, TOOLKIT, COPY);
				exit(EXIT_SUCCESS);
			default:
				fprintf(stderr, "%s: try '--help' for more information\n", PROGRAM);
				exit(EXIT_FAILURE);
		}
	}

	return options;
}

/* MEW Packer and others basically stores the entrypoint
   in a section marked only as readable (without
   executable and/or writable flags)
   Windows Loader still executes the binary
*/
static bool generic_packer(pe_ctx_t *ctx, uint64_t entrypoint)
{
	unsigned char packer = '0';
	IMAGE_SECTION_HEADER *sec = pe_rva2section(ctx, entrypoint);

   // we count the flags for the section and if there is more than
   // 2 it means we don't have the mew_packer
   unsigned int invalid_flags[] = { 0x20000000, 0x40000000, 0x80000000 };

	if (!sec)
		return false;

	// MEW never leave EP in .text section
	if (!memcmp(sec->Name, ".text", 5))
		return false;

	for (unsigned int j=0; j < LIBPE_SIZEOF_ARRAY(invalid_flags); j++)
	{
		if (sec->Characteristics & invalid_flags[j])
			packer++;
	}

   return packer < '3';
}

static bool loaddb(FILE **fp, const options_t *options)
{
	const char *dbfile = options->dbfile ? options->dbfile : "userdb.txt";

	*fp = fopen(dbfile, "r");	
	if (!*fp) {
		// TODO(jweyrich): This might change - Should we use a config.h with a constant from $(SHAREDIR)?
		*fp = fopen("/usr/share/pev/userdb.txt", "r");
	}

	return *fp != NULL;
}

static bool match_peid_signature(const unsigned char *data, char *sig)
{
	unsigned char byte_str[3], byte;
	
	// add null terminator
	byte_str[2] = '\0';
	
	while (*sig)
	{
		// ignore '=' and blank spaces
		if (*sig == '=' || *sig == ' ')
		{
			sig++;
			continue;
		}

		// match "??"
		if (*sig == '?')
		{
			sig += 2;
			data++;
			continue;
		}

		memcpy(byte_str, sig, 2);
		byte = strtoul((char *) byte_str, NULL, 16);

		if (*data++ != byte)
			return false;

		sig += 2; // next two characters of signature
	}
	return true;
}

static bool compare_signature(const unsigned char *data, uint64_t ep_offset, FILE *dbfile, char *packer_name, size_t packer_name_len)
{
	if (!dbfile || !data)
		return false;

	char *buff = malloc_s(MAX_SIG_SIZE);

	//memset(buff, 0, MAX_SIG_SIZE);
	while (fgets(buff, MAX_SIG_SIZE, dbfile))
	{
		// line length
		size_t len = strlen(buff);
		
		// ifgore comments and blank lines
		if (*buff == ';' || *buff == '\n' || *buff == '\r')
			continue;
		
		// remove newline from buffer
		if (*(buff+len-1) == '\n')
			*(buff+len-1) = '\0';
		
		// removing carriage return, if present
		if (*(buff+len-2) == '\r')
		{
			*(buff+len-2) = '\0';
			//*(buff+len-1) = '\0';
			len--; // update line length
		}
		
		// line have [packer name]? Fill packer_name pointer
		if (*buff == '[' && *(buff+len-2) == ']')
		{
			*(buff+len-2) = '\0'; // remove square brackets
			strncpy(packer_name, buff+1, packer_name_len);
			packer_name[packer_name_len-1] = '\0'; // Guarantee it's Null-terminated.
		}
		
		// check if signature match
		if (!strncasecmp(buff, "signature", 9))
		{
			if (match_peid_signature(data + ep_offset, buff+9))
			{
				free(buff);
				return true;
			}
		}
	}
	free(buff);
	return false;
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

	pe_err_e err = pe_load_file(&ctx, path);
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

	uint64_t ep_offset = pe_rva2ofs(&ctx, ctx.pe.entrypoint);
	if (ep_offset == 0)
		EXIT_ERROR("unable to get entrypoint offset");
	
	// TODO(jweyrich): Create a new API to retrieve map_addr.
	// TODO(jweyrich): Should we use `LIBPE_PTR_ADD(ctx->map_addr, ep_offset)` instead?
	const unsigned char *pe_data = ctx.map_addr;
	
	FILE *dbfile = NULL;
	if (!loaddb(&dbfile, options))
		fprintf(stderr, "warning: without valid database file, %s will search in generic mode only\n", PROGRAM);
	
	char value[MAX_MSG];

	// packer by signature
	if (compare_signature(pe_data, ep_offset, dbfile, value, sizeof(value)))
		;
	// generic detection
	else if (generic_packer(&ctx, ep_offset))
		snprintf(value, MAX_MSG, "generic");
	else
		snprintf(value, MAX_MSG, "no packer found");
	
	output("packer", value);

	if (dbfile)
		fclose(dbfile);

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
