library(XML)
doc = xmlParse("doc.xml")
dyn.load("fib.so")
fib.ptr = getNativeSymbolInfo('xpathFib')$address
cc = getNodeSet(doc, "//value[ fib(number(.)) > 10 ]", xpathFuns = list(fib = fib.ptr))




