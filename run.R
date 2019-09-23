library(XML)
doc = xmlParse("doc.xml")

library(Rllvm)
m = parseIR("fib.ll")
llvmAddSymbol("xmlXPathPopNumber", "xmlXPathNewFloat", "valuePush")

ee = ExecutionEngine(m)

llfib.ptr = getPointerToFunction(m$xpathFib, ee)@ref

ll = getNodeSet(doc, "//value[ fib(number(.)) > 10 ]", xpathFuns = list(fib = llfib.ptr))
