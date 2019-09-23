if(FALSE) {
library(Rllvm)
m = parseIR("fibOnly.ll")
source("genXPathWrapper.R")
m2 = clone(m)
genXPathWrapper(m2$fib)
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
     
     f
}

popArg =
function(ir, ty, ctxt, module)
{

    # Add the definition for xmlXPathPop....
    #XXX generalize
   xmlXPathPopNumber = Function("xmlXPathPopNumber", DoubleType, list(pointerType(VoidType)), module = module)    
   k = createCall(ir, xmlXPathPopNumber, ctxt)

   if(!identical(getType(k) , ty)) {
       #XX generalize
     createCast(ir, Rllvm:::FPToSI, k, ty)
   } else
     k
}

pushResult =
function(ir, val, retType, ctxt, module)
{
    xmlXPathNewFloat = Function("xmlXPathNewFloat", pointerType(VoidType), list(DoubleType), module = module)
browser()
    if(!identical(DoubleType, retType))
        val = createCast(ir, Rllvm:::SIToFP, val, DoubleType)
    xval = createCall(ir, xmlXPathNewFloat, val)

    valuePush = Function("valuePush", Int32Type, list(pointerType(VoidType), pointerType(VoidType)))
    createCall(ir, valuePush, ctxt, xval)
}
