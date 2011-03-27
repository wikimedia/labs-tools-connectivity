#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

void parseChain(char* source) {
	int i, j=0, orphCount=0;
	int chainL=0;	// number of nodes in the chain
	char curNode[8];

	for(i=0;i<strlen(source);++i)
		if(source[i]=='_')
			++chainL;	// getting the number of nodes

	int nodes[chainL];

	for(i=0;i<strlen(source);++i) {
		if(isdigit(source[i])) {
			nodes[j++] = atoi(source+i);	// placing next node to the array
			if(isdigit(source[++i]))
				for(;isdigit(source[i]);++i)	// if node value >9 then
					;							// skipping characters to get the next node
		}
	}

	for(i=0;i<chainL;++i) {
		if(nodes[i]==2) {
			printf("ring2");
		} else if(nodes[i]>2) {
			printf("cluster%i", nodes[i]);
		} else {
			while((nodes[i]==1) && (i<chainL)) {
				++orphCount;
				++i;
			}
			printf("orphan%i", orphCount-1);
			orphCount=0;
			--i;
		}
	}
	printf("\n");
}

int main(int argc, char **argv) {
	int i;
	if(argc==1 || argc > 2) {
		printf("Wrong arguments.\nsyntax: chain_parser [chain]\n");
		return 1;
	} else if(!(strcmp(argv[1], "-h"))) {
		printf("syntax: %s [chain]\n", argv[0]);
		return 0;
	} else {
		parseChain(argv[1]);
	}

	return 0;
}
