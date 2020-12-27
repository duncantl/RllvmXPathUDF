library(Rllvm)

source("genXPathWrapper.R")

if(FALSE) {
library(RCIndex)
tu  = createTU("/usr/local/include/pcre2.h")
r = getRoutines(tu)
grep("pcre2_compile", names(r), value = TRUE) 
# Note the _8 and _16 versions of these functions. We'll use the _8 versions.

ds = getDataStructures(tu)
}


# The pattern we will look for. We are hard-coding the value  in this version.
# It is probably easier to allow the R user to specify this and hence change it as we did in regex.c
# This is because we don't have to work with string literals but directly with pointers from R.
regex = "foo"

m = Module()

# Declare opaque structures. We can probably just use vptrType below as a void *
real_match_data = structType(character(), name = "struct.real_match_data", withNames = FALSE)
real_code = structType(character(), name = "struct.real_code", withNames = FALSE)
preal_match_data = pointerType(real_match_data)


vptrType = pointerType(VoidType)

# NULL value for pointers to 8 and 32 integers
null = getNULLPointer(pointerType(Int8Type)) # VoidType)
null32 = getNULLPointer(pointerType(Int32Type)) # VoidType)


# Declarations of routines we will use.
# Don't actually need strlen() as we can use PCRE2_ZERO_TERMINATED (i.e. -1 as an Int64Type)
strlen = Function("strlen", Int32Type, list(StringType), module = m)
pcre2_match = Function("pcre2_match_8", Int32Type, list(pointerType(real_code), StringType, Int64Type, Int32Type, Int32Type, pointerType(real_match_data), vptrType), module = m)
pcre2_match_data_create = Function("pcre2_match_data_create_8", pointerType(real_match_data), list(Int32Type, vptrType), module = m)

iptrType = pointerType(Int32Type)
pcre2_compile = Function("pcre2_compile_8", pointerType(real_code),
                          list(StringType, Int64Type, Int32Type, iptrType, iptrType, vptrType), module = m)

printf = Function("printf", Int32Type, list(StringType), module = m, varArgs = TRUE)


# Two global variables - matchData we use in pcre2_compile and pattern which is the compiled regular expression object we use in pcre2_match
pattern = createGlobalVariable("pattern", m, pointerType(real_code), NULL, alignment = 8L) # vptrType) # , linkage = InternalLinkage)
matchData = createGlobalVariable("matchData", m, pointerType(real_match_data), NULL, alignment = 8L) # vptrType) #, linkage = InternalLinkage)
setUnnamedAddr(pattern, Rllvm:::Local)
setUnnamedAddr(matchData, Rllvm:::Local)



# An initialize() routine which will call pcre2_match_data_create() and pcre2_compile()
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
#Works but we'll use -1L for PCRE2_ZERO_TERMINATED instead of calling strlen().
# crx = ir$createCall(pcre2_compile, ir$createGEP(rxv, c(0L, 0L)), ir$createConstant(nchar(regex), Int64Type), zero, null32, null32, null)
crx = ir$createCall(pcre2_compile, ir$createGEP(rxv, c(0L, 0L)), ir$createConstant(-1L, Int64Type), zero, null32, null32, null)

fmt3 = createGlobalVariable("printf.fmt3", m, val = ir$createConstant("pattern = %p\n"), constant = TRUE, align = 1L)
ir$createCall(printf, ir$createGEP(fmt3, c(0L, 0L)), crx)

ir$createStore(crx, pattern)
ir$createReturn()


########################

# The match function
f1 = simpleFunction("do_match", Int1Type, str = StringType, mod = m)
ir = f1$ir

# Debugging
fmt1 = createGlobalVariable("printf.fmt1", m, val = ir$createConstant("string = %s\n"), constant = TRUE, align = 1L)
ir$createCall(printf, ir$createGEP(fmt1, c(0L, 0L)), f1$params$str)

# Instead of strlen() call, we could use PCRE2_ZERO_TERMINATED which is ~ 0   -1 as a 64 bit integer
#len = ir$createCall(strlen, f1$params$str)
len = ir$createConstant(-1L, Int64Type)
ans = ir$createCall(pcre2_match, ir$createLoad(pattern), f1$params$str, len, zero, zero, ir$createLoad(matchData), null)
ans2 = ir$createICmp(ICMP_SGT, ans, zero)

fmt2 = createGlobalVariable("printf.fmt2", m, val = ir$createConstant("ans = %d, pattern = %p\n"), constant = TRUE, align = 1L)
ir$createCall(printf, ir$createGEP(fmt2, c(0L, 0L)), ans2, ir$createLoad(pattern))

ir$createReturn(ans2)

if(FALSE) {
    wrapper = genXPathWrapper(f1, retType = Int1Type, module = m, funName = "xpath_grepl")
}

verifyModule(m)

if(FALSE) {
    # Load the native libaries and pass the relevant address to LLVM
    # pcre.p2 = dyn.load("/usr/local/lib/libpcre2-posix.2.dylib")
    pcre2 = dyn.load("/usr/local/lib/libpcre2-8.0.dylib")
    llvmAddSymbol("printf", "strlen", pcre2_match = "pcre2_match_8", pcre2_compile = "pcre2_compile_8", pcre2_match_data_create = "pcre2_match_data_create_8")

    ee = ExecutionEngine(m)
    .llvm(m$initialize, .ee = ee)
    .llvm(m$do_match, "xyz")
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
