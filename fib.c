//#include <stdio.h>
#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>

int
fib(int n)
{
    if(n < 2)
	return(n);
    
//    fprintf(stdout, "fib: %d\n", n);
    return(fib(n-1) + fib(n-2));
}

void
xpathFib(xmlXPathParserContextPtr ctxt, int nargs)
{
    float num = xmlXPathPopNumber(ctxt); 
    xmlXPathReturnNumber(ctxt, fib((int) num));
}
