#include <Rdefines.h>

#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>

pcre2_match_data *matchData = NULL;
pcre2_code *pattern = NULL;

SEXP
R_setPattern(SEXP r_pattern)
{
    int errno = 0;
    PCRE2_SIZE erroroff = 0;
    matchData = pcre2_match_data_create(4, NULL);
    pattern = pcre2_compile(CHAR(STRING_ELT(r_pattern, 0)), PCRE2_ZERO_TERMINATED, 0, &errno, &erroroff, NULL);
    // no reason to return PCRE2_ZERO_TERMINATED other than to see what its value is since it is defined via a macro as ~ (PCRE_SIZE) 0 
    return(ScalarReal(PCRE2_ZERO_TERMINATED)); // R_NilValue);
}


#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>

void
do_match(xmlXPathParserContextPtr ctxt, int nargs)
{
    xmlChar *str = xmlXPathPopString(ctxt);
    int rc = pcre2_match(pattern, str, PCRE2_ZERO_TERMINATED, 0, 0, matchData, NULL);
    xmlXPathReturnBoolean(ctxt, rc > 0);
}
