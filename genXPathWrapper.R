if(FALSE) {
library(Rllvm)
m = parseIR("fibOnly.ll")
source("genXPathWrapper.R")
m2 = clone(m)
xp = genXPathWrapper(m2$fib)

library(XML)
llvmAddSymbol("xmlXPathPopNumber", "xmlXPathNewFloat", "valuePush")

ee = ExecutionEngine(m2)
xp  = getPointerToFunction(m2$xpathfib, ee)@ref


doc = xmlParse("doc.xml")
ll = getNodeSet(doc, "//value[ fib(number(.)) > 10 ]", xpathFuns = list(fib = xp))
}

genXPathWrapper =
    #
    #
    #
    #
    #
function(fun, params = getParameters(fun), retType = getReturnType(fun), module = as(fun, "Module"),
          funName = sprintf("xpath%s", getName(fun)))
{
     f = Function(funName, VoidType, list(ctxt = pointerType(VoidType), nargs = Int32Type), module = module)
     
      #XX Add a check for nargs

     nparams = getParameters(f)
     ctxt = nparams[[1]]
     b = Block(f)
     ir = IRBuilder(b)

     args = lapply(params, function(p)
                              popArg(ir, getType(p), ctxt, module))

      # call the function being wrapped, i.e. the original function of interest.
     val = createCall(ir, fun, .args = args)

     pushResult(ir, val, retType, ctxt, module)

     createReturn(ir)
     
     f
}

popArg =
function(ir, ty, ctxt, module)
{

    # Add the definition for xmlXPathPop....
    #XXX generalize
    if(identical(ty, Int1Type))
       pop = Function("xmlXPathPopBoolean", Int32Type, list(pointerType(VoidType)), module = module)        
    else if(isIntegerType(ty) || identical(ty, DoubleType)) 
       pop = Function("xmlXPathPopNumber", DoubleType, list(pointerType(VoidType)), module = module)
    else if(identical(StringType, ty))
       pop = Function("xmlXPathPopString", pointerType(Int32Type), list(pointerType(VoidType)), module = module)
    else  #XXX
        pop = Function("xmlXPathPopNodeSet", pointerType(Int32Type), list(pointerType(VoidType)), module = module)                
   k = createCall(ir, pop, ctxt)

   if(!identical(getType(k) , ty)) {
       #XX generalize
     createCast(ir, Rllvm:::FPToSI, k, ty)
   } else
     k
}

pushResult =
function(ir, val, retType, ctxt, module)
{
browser()    
    if(identical(retType, Int1Type))
       xnew = Function("xmlXPathNewBoolean", pointerType(VoidType), list(Int32Type), module = module)        
    else if(isIntegerType(retType) || identical(DoubleType, retType))
       xnew = Function("xmlXPathNewFloat", pointerType(VoidType), list(DoubleType), module = module)
    else if(identical(StringType, retType) || (isPointerType(retType) && identical(Int8Type, getElementType(retType))))
        xnew = Function("xmlXPathNewCString", pointerType(VoidType), list(StringType), module = module)
    else
        stop("no matching type")

    ty = getType(getParameters(xnew)[[1]])
    if(!identical(ty, retType)) {
        val = createCast(ir, Rllvm:::SIToFP, val, ty)
    }
    
    xval = createCall(ir, xnew, val)

    valuePush = Function("valuePush", Int32Type, list(pointerType(VoidType), pointerType(VoidType)), module = module)
    createCall(ir, valuePush, ctxt, xval)
}
