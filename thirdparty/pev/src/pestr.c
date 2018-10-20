/*
	pev - the PE file analyzer toolkit
	
	pestr.c - search for [encrypted] strings in PE files

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
#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <pcre.h>

#define PROGRAM "pestr"
#define BUFSIZE 4
#define OVECCOUNT 30
#define LINE_BUFFER 32768

typedef struct {
	unsigned short strsize;
	bool offset;
	bool section;
	bool functions;
	bool net;
} options_t;

static void usage(void)
{
	printf("Usage: %s OPTIONS FILE\n"
		"Search for [encrypted] strings in PE files\n"
		"\nExample: %s acrobat.exe\n"
		"\nOptions:\n"
		" -n, --min-length                       set minimun string length (default: 4)\n"
		" -o, --offset                           show string offset in file\n"
		" -s, --section                          show string section, if exists\n"
		" --net                                  show network-related strings (IPs, hostnames etc)\n"
		" -v, --version                          show version and exit\n"
		" --help                                 show this help and exit\n",
		PROGRAM, PROGRAM);
}

static void free_options(options_t *options)
{
	if (options == NULL)
		return;

	free(options);
}

static options_t *parse_options(int argc, char *argv[])
{
	options_t *options = malloc_s(sizeof(options_t));
	memset(options, 0, sizeof(options_t));

	/* Parameters for getopt_long() function */
	static const char short_options[] = "fosn:v";

	static const struct option long_options[] = {
		{ "functions",       no_argument,        NULL, 'f' },
		{ "offset",          no_argument,        NULL, 'o' },
		{ "section",         no_argument,        NULL, 's' },
		{ "min-length",      required_argument,  NULL, 'n' },
		{ "help",            no_argument,        NULL,  1  },
		{ "version",         no_argument,        NULL,  3  },
		{ "net",             no_argument,        NULL,  2  },
		{ NULL,              0,                  NULL,  0  }
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
			case 2:
				options->net = true;
				break;
			case 'f':
				//options->functions = true;
				EXIT_ERROR("not implemented yet");
				break;
			case 'n':
			{
				unsigned long value = strtoul(optarg, NULL, 0);
				if (value == ULONG_MAX && errno == ERANGE) {
					fprintf(stderr, "The original (nonnegated) value would overflow");
					exit(EXIT_FAILURE);
				}
				options->strsize = (unsigned char)value;
				break;
			}
			case 'o':
				options->offset = true;
				break;
			case 's':
				options->section = true;
				break;
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

static unsigned char *ofs2section(pe_ctx_t *ctx, uint64_t offset)
{
	IMAGE_SECTION_HEADER **sections = pe_sections(ctx);

	for (uint16_t i=0; i < ctx->pe.num_sections; i++) {
		uint32_t sect_offset = sections[i]->PointerToRawData;
		uint32_t sect_size = sections[i]->SizeOfRawData;

		if (offset >= sect_offset && offset <= (sect_offset + sect_size)) {
			return (unsigned char *)sections[i]->Name;
		}
	}

	return NULL;
}

typedef enum {
	ENCODING_ASCII = 0,
	ENCODING_UNICODE = 1
} encoding_t;

static bool ishostname(const char *s, const encoding_t encoding)
{
	const char *patterns[] = {
		"^[a-zA-Z]{3,}://.*$", // protocol://
		"[1-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}:?" // ipv4
	};

	const char *domains[] = {
".asia", ".jobs", ".mobi", ".travel", ".xxx",
".aero", ".arpa", ".biz", ".com", ".coop", ".edu", ".gov", ".info", ".int", ".jus", ".mil",
".museum", ".name", ".net", ".org", ".pro", ".ac", ".ad", ".ae", ".af", ".ag", 
".ai", ".al", ".am", ".an", ".ao", ".aq", ".ar", ".as", ".at", ".au", ".aw", ".az", ".ba",
".bb", ".bd", ".be", ".bf", ".bg", ".bh", ".bi", ".bj", ".bm", ".bn", ".bo", ".br", ".bs",
".bt", ".bv", ".bw", ".by", ".bz", ".ca", ".cc", ".cd", ".cf", ".cg", ".ch", ".ci", ".ck",
".cl", ".cm", ".cn", ".co", ".cr", ".cu", ".cv", ".cx", ".cy", ".cz", ".de", ".dj", ".dk",
".dm", ".do", ".dz", ".ec", ".ee", ".eg", ".er", ".es", ".et", ".eu", ".fi", ".fj", ".fk",
".fm", ".fo", ".fr", ".ga", ".gb", ".gd", ".ge", ".gf", ".gg", ".gh", ".gi", ".gl", ".gm",
".gn", ".gp", ".gq", ".gr", ".gs", ".gt", ".gu", ".gw", ".gy", ".hk", ".hm", ".hn", ".hr",
".ht", ".hu", ".id", ".ie", ".il", ".im", ".in", ".io", ".iq", ".ir", ".is", ".it", ".je",
".jm", ".jo", ".jp", ".ke", ".kg", ".kh", ".ki", ".km", ".kn", ".kr", ".kw", ".ky", ".kz",
".la", ".lb", ".lc", ".li", ".lk", ".lr", ".ls", ".lt", ".lu", ".lv", ".ly", ".ma", ".mc",
".md", ".me", ".mg", ".mh", ".mk", ".ml", ".mm", ".mn", ".mo", ".mp", ".mq", ".mr", ".ms",
".mt", ".mu", ".mv", ".mw", ".mx", ".my", ".mz", ".nb", ".nc", ".ne", ".nf", ".ng", ".ni",
".nl", ".no", ".np", ".nr", ".nu", ".nz", ".om", ".pa", ".pe", ".pf", ".pg", ".ph", ".pk",
".pl", ".pm", ".pn", ".pr", ".ps", ".pt", ".pw", ".py", ".qa", ".re", ".ro", ".ru", ".rw",
".sa", ".sb", ".sc", ".sd", ".se", ".sg", ".sh", ".si", ".sj", ".sk", ".sl", ".sm", ".sn",
".so", ".sr", ".ss", ".st", ".su", ".sv", ".sy", ".sz", ".tc", ".td", ".tf", ".tg", ".th",
".tj", ".tk", ".tl", ".tm", ".tn", ".to", ".tr", ".tt", ".tv", ".tw", ".tz", ".ua", ".ug",
".uk", ".um", ".us", ".uy", ".uz", ".va", ".vc", ".ve", ".vg", ".vi", ".vn", ".vu", ".wf",
".ws", ".ye", ".yt", ".yu", ".za", ".zm", ".zw"
	};

	if (!isalnum((int) *s))
		return false;

	const size_t s_len = strlen(s);

	for (size_t i=0; i < LIBPE_SIZEOF_ARRAY(domains); i++) {
		// TODO: unicode equivalent
		const char *p = s + (s_len - strlen(domains[i]));
		if (strcasestr(p, domains[i]))
			return true;
	}

	int ovector[OVECCOUNT];

	for (size_t i=0; i < LIBPE_SIZEOF_ARRAY(patterns); i++) {
		const char *err;
		int errofs;
		pcre *re = pcre_compile(patterns[i], (encoding == ENCODING_UNICODE) ? PCRE_UCP : 0, &err, &errofs, NULL);
		if (!re)
			EXIT_ERROR("regex compilation failed");

		int rc = pcre_exec(re, NULL, s, LINE_BUFFER, 0, 0, ovector, OVECCOUNT);
		pcre_free(re);

		if (rc > 0)
			return true;
	}

	return false;
}

static void printb(
	pe_ctx_t *ctx,
	const options_t *options,
	const uint8_t *bytes,
	size_t pos,
	size_t length,
	unsigned long offset
) {
	if (options->offset)
		printf("%#lx\t", (unsigned long) offset);

	if (options->section) {
		char *s = (char *) ofs2section(ctx, offset);
		printf("%s\t", s ? s : "[none]");
	}

	if (options->functions) {
		uint64_t rva = pe_ofs2rva(ctx, offset);
		printf("%#"PRIx64"\t", rva); // snprintf takes care of Null-termination.
	}

	// print the string
	while (pos < length) {
		if (bytes[pos] == '\0') { // unicode printing
			pos++;
			continue;
		}
		putchar(bytes[pos++]);
	}

	putchar('\n');
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

	const uint64_t pe_size = pe_filesize(&ctx);
	const uint8_t *pe_raw_data = ctx.map_addr;
	uint64_t pe_raw_offset = 0;

	unsigned char buff[LINE_BUFFER];
	memset(buff, 0, LINE_BUFFER);
	uint64_t buff_index = 0;

	uint32_t ascii = 0;
	uint32_t utf = 0;

	while (pe_raw_offset < pe_size) {
		const uint8_t byte = pe_raw_data[pe_raw_offset];

		if (isprint(byte)) {
			ascii++;
			buff[buff_index++] = byte;
			pe_raw_offset++;
			continue;
		} else if (ascii == 1 && byte == '\0') {
			utf++;
			buff[buff_index++] = byte;
			ascii = 0;
			pe_raw_offset++;
			continue;
		} else {
			if (ascii >= (options->strsize ? options->strsize : 4)) {
				if (options->net) {
					if (ishostname((char *) buff, ENCODING_ASCII))
						printb(&ctx, options, buff, 0, ascii, pe_raw_offset - ascii);
				} else {
					printb(&ctx, options, buff, 0, ascii, pe_raw_offset - ascii);
				}
			} else if (utf >= (options->strsize ? options->strsize : 4)) {
				if (options->net) {
					if (ishostname((char *) buff, ENCODING_UNICODE))
						printb(&ctx, options, buff, 0, utf*2, pe_raw_offset - utf*2);
				} else {
					printb(&ctx, options, buff, 0, utf*2, pe_raw_offset - utf*2);
				}
			}
			ascii = utf = buff_index = 0;
			memset(buff, 0, LINE_BUFFER);
		}

		pe_raw_offset++;
	}
	
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
