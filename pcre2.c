#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>

#include <stdio.h>

#define SZ(t) fprintf(stderr,  "%s %ld\n", #t, sizeof(t))

int
main(int argc, char *argv[])
{
    SZ(uint32_t);
    SZ(size_t);
    SZ(int);
    SZ(long);
    SZ(long long);
    SZ(double);
    SZ(long double);    
	
    return(0);
}
