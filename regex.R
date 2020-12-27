dyn.load("regex.so")
.Call("R_setPattern", "foo")

library(XML)
doc = xmlParse("doc3.xml")
# Find any node which has an immediate/direct text child matching foo - foo and fool.
els = getNodeSet(doc, "//text()[grep_p(string(.))]/..", xpathFuns = list(grep_p = getNativeSymbolInfo("do_match")$address))

# Find any node which has a tag attribute for which foo matches.
els = getNodeSet(doc, "//*[grep_p(@tag)]", xpathFuns = list(grep_p = getNativeSymbolInfo("do_match")$address))


# Now find any node with a tag attribute that foo or abc matches the tag value.
.Call("R_setPattern", "foo|abc")

els = getNodeSet(doc, "//*[grep_p(@tag)]", xpathFuns = list(grep_p = getNativeSymbolInfo("do_match")$address))






