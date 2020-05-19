/*
 * Listen to the kobject uevent netlink socket and print
 * the messages to stdout as they arrive.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <linux/netlink.h>

void hexdump(
	const void * buf,
	size_t len
)
{
	for(size_t i = 0 ; i < len ; i++)
		printf("%02x", ((const uint8_t*) buf)[i]);
	printf("\n");
}

int main(void)
{
	int one_line = 0;

	int sock = socket(PF_NETLINK, SOCK_RAW, NETLINK_KOBJECT_UEVENT);
	if (sock < 0)
	{
		perror("netlink");
		return EXIT_FAILURE;
	}

	struct sockaddr_nl src_addr = {
		.nl_family	= AF_NETLINK,
		.nl_pid		= getpid(),
		.nl_groups	= 1,
	};

	if (bind(sock, (struct sockaddr*) &src_addr, sizeof(src_addr)) < 0)
	{
		perror("bind");
		return EXIT_FAILURE;
	}

	uint8_t data[4096];

	while(1)
	{
		ssize_t rc = recv(sock, data, sizeof(data), 0);
		if (rc < 0)
		{
			perror("recv");
			return EXIT_FAILURE;
		}

		if (one_line)
		{
			for(ssize_t i = 0 ; i < rc-1 ; i++)
				if (data[i] == 0)
					data[i] = '|';
			printf("%s\n", (const char*) data);
			continue;
		}

		ssize_t offset = 0;
		while(offset < rc)
		{
			const char * msg = (const char *) &data[offset];
			printf("%s%s\n",
				offset == 0 ? "" : "\t",
				msg
			);

			offset += strlen(msg) + 1;
		}
	}
}
