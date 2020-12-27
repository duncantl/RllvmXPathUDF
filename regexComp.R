library(Rllvm)

source("genXPathWrapper.R")

if(FALSE) {
library(RCIndex)
tu  = createTU("/usr/local/include/pcre2.h")
r = getRoutines(tu)
grep("pcre2_compile", names(r), value = TRUE)
# Note the _8 and _16 versions of these functions.

ds = getDataStructures(tu)
}

regex = "foo"

m = Module()

real_match_data = structType(character(), name = "struct.real_match_data", withNames = FALSE)
real_code = structType(character(), name = "struct.real_code", withNames = FALSE)
preal_match_data = pointerType(real_match_data)


vptrType = pointerType(VoidType)
null = getNULLPointer(pointerType(Int8Type)) # VoidType)
null32 = getNULLPointer(pointerType(Int32Type)) # VoidType)

strlen = Function("strlen", Int32Type, list(StringType), module = m)
pcre2_match = Function("pcre2_match_8", Int32Type, list(pointerType(real_code), StringType, Int32Type, Int32Type, Int32Type, pointerType(real_match_data), vptrType), module = m)
pcre2_match_data_create = Function("pcre2_match_data_create_8", pointerType(real_match_data), list(Int32Type, vptrType), module = m)

iptrType = pointerType(Int32Type)
pcre2_compile = Function("pcre2_compile_8", pointerType(real_code),
                          list(StringType,   # arrayType(Int8Type, 4), 
                               Int64Type, Int32Type, iptrType, iptrType, vptrType), module = m)


printf = Function("printf", Int32Type, list(StringType), module = m)

pattern = createGlobalVariable("pattern", m, pointerType(real_code), NULL, alignment = 8L) # vptrType) # , linkage = InternalLinkage)
matchData = createGlobalVariable("matchData", m, pointerType(real_match_data), NULL, alignment = 8L) # vptrType) #, linkage = InternalLinkage)

setUnnamedAddr(pattern, Rllvm:::Local)
setUnnamedAddr(matchData, Rllvm:::Local)



f2 = simpleFunction("initialize", VoidType, .types = list(), mod = m)
ir = f2$ir

zero = ir$createConstant(0L)
md = ir$createCall(pcre2_match_data_create, ir$createConstant(4L), null)

ir$createStore(md, matchData)


rx = ir$createConstant("foo")
rxv = createGlobalVariable("regex", m, val = rx, type = getType(rx), constant = TRUE, align = 1L)
setUnnamedAddr(rxv, "Local")


#XXX add the error handlers.
#crx = ir$createCall(pcre2_compile, ir$createConstant(regex), ir$createConstant(nchar(regex)), zero, null32, null32, null)
#crx = ir$createCall(pcre2_compile, rx, ir$createConstant(nchar(regex)), zero, null32, null32, null)
#Works
# crx = ir$createCall(pcre2_compile, ir$createGEP(rxv, c(0L, 0L)), ir$createConstant(nchar(regex), Int64Type), zero, null32, null32, null)
crx = ir$createCall(pcre2_compile, ir$createGEP(rxv, c(0L, 0L)), ir$createConstant(-1L, Int64Type), zero, null32, null32, null)
ir$createStore(crx, pattern)
ir$createReturn()


# The match function
f1 = simpleFunction("do_match", Int1Type, str = StringType, mod = m)
ir = f1$ir

# Instead of strlen() call, we could use PCRE2_ZERO_TERMINATED which is ~ 0   -1 as a 64 bit integer
len = ir$createCall(strlen, f1$params$str)
ans = ir$createCall(pcre2_match, ir$createLoad(pattern), f1$params$str, len, zero, zero, ir$createLoad(matchData), null)
ans2 = ir$createICmp(ICMP_SGT, ans, zero)
ir$createReturn(ans2)

if(FALSE) {
    wrapper = genXPathWrapper(f1, retType = Int1Type, module = m, funName = "xpath_grepl")
}

verifyModule(m)

if(FALSE) {
    pcre.p2 = dyn.load("/usr/local/lib/libpcre2-posix.2.dylib")
    pcre2 = dyn.load("/usr/local/lib/libpcre2-8.0.dylib")
    llvmAddSymbol("printf", "strlen", pcre2_match = "pcre2_match_8", pcre2_compile = "pcre2_compile_8", pcre2_match_data_create = "pcre2_match_data_create_8")
    ee = ExecutionEngine(m)
    .llvm(m$initialize, .ee = ee)
}









###################################
if(FALSE) {
    # If we were to build the wrapper ourselves, it would be along the following skeleton ....

    
Function("valuePush", VoidType, list(vptrType))

# f = Function("do_match", VoidType, list(ctxt = vptrType, nargs = Int32Type), module = m)
fn = simpleFunction("do_match", VoidType, .types = list(ctxt = vptrType, nargs = Int32Type), mod = m)
ir = fn$ir

str = popArg(ir, StringType, fn$params$ctxt, m)

ans = ir$createCall(pcre2_match, pattern, str, , 0L, 0L, matchData, 0L)
ans2 = ir$binOp(ICMP_SGT, ans, 0)
val = ir$createCall(xmlXPathNewBoolean, ans2)
ir$createCall(valuePush, val)
}
